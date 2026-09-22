<?php

namespace App\Http\Controllers;

use App\Models\Student;
use App\Models\Classroom;
use Illuminate\Http\Request;
use Inertia\Inertia;

class StudentController extends Controller
{
    public function index(Request $request)
    {
        $query = Student::with('classroom.major');

        // Search Filter
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('nama', 'like', "%{$search}%")
                  ->orWhere('nis', 'like', "%{$search}%")
                  ->orWhere('nisn', 'like', "%{$search}%");
            });
        }

        // Classroom Filter
        if ($request->filled('classroom_id')) {
            $query->where('classroom_id', $request->input('classroom_id'));
        }

        // Gender Filter
        if ($request->filled('jenis_kelamin')) {
            $query->where('jenis_kelamin', $request->input('jenis_kelamin'));
        }

        $students = $query->latest()->paginate(10)->withQueryString();
        $classrooms = Classroom::with('major')->orderBy('nama')->get();

        return Inertia::render('Siswa/Index', [
            'students' => $students,
            'filters' => $request->only(['search', 'classroom_id', 'jenis_kelamin']),
            'classrooms' => $classrooms,
            'flash' => [
                'success' => session('success')
            ]
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'nis' => 'required|string|max:20|unique:students,nis',
            'nisn' => 'nullable|string|max:20|unique:students,nisn',
            'nama' => 'required|string|max:100',
            'classroom_id' => 'required|exists:classrooms,id',
            'jenis_kelamin' => 'required|in:L,P',
            'alamat' => 'required|string',
            'hp' => 'required|string|max:20',
            'hp_ortu' => 'nullable|string|max:20',
        ]);

        // Sync old text column for maximum compatibility
        $classroom = Classroom::find($validated['classroom_id']);
        $validated['kelas'] = $classroom ? $classroom->nama : '';

        Student::create($validated);

        return redirect()->back()->with('success', 'Siswa berhasil ditambahkan!');
    }

    public function update(Request $request, Student $siswa)
    {
        $validated = $request->validate([
            'nis' => 'required|string|max:20|unique:students,nis,' . $siswa->id,
            'nisn' => 'nullable|string|max:20|unique:students,nisn,' . $siswa->id,
            'nama' => 'required|string|max:100',
            'classroom_id' => 'required|exists:classrooms,id',
            'jenis_kelamin' => 'required|in:L,P',
            'alamat' => 'required|string',
            'hp' => 'required|string|max:20',
            'hp_ortu' => 'nullable|string|max:20',
        ]);

        // Sync old text column for maximum compatibility
        $classroom = Classroom::find($validated['classroom_id']);
        $validated['kelas'] = $classroom ? $classroom->nama : '';

        $siswa->update($validated);

        return redirect()->back()->with('success', 'Siswa berhasil diperbarui!');
    }

    public function destroy(Student $siswa)
    {
        $siswa->delete();

        return redirect()->back()->with('success', 'Siswa berhasil dihapus!');
    }

    public function downloadTemplate()
    {
        $spreadsheet = new \PhpOffice\PhpSpreadsheet\Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        
        // Header
        $headers = [
            'NIS',
            'NISN',
            'Nama Siswa',
            'Jenis Kelamin (L/P)',
            'Kelas',
            'Alamat',
            'HP Siswa',
            'HP Orang Tua'
        ];
        
        foreach ($headers as $colIndex => $header) {
            $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($colIndex + 1);
            $sheet->setCellValue($colLetter . '1', $header);
            $sheet->getStyle($colLetter . '1')->getFont()->setBold(true);
        }

        // Add a sample row to guide user
        $sheet->setCellValue('A2', '24250199');
        $sheet->setCellValue('B2', '0089876543');
        $sheet->setCellValue('C2', 'Budi Hartono');
        $sheet->setCellValue('D2', 'L');
        
        $classroom = Classroom::first();
        $sheet->setCellValue('E2', $classroom ? $classroom->nama : 'XII RPL 1');
        
        $sheet->setCellValue('F2', 'Jl. Mastrip No. 12, Jember');
        $sheet->setCellValue('G2', '081234567890');
        $sheet->setCellValue('H2', '081234567891');

        // Reference classes list
        $sheet->setCellValue('J1', 'Daftar Kelas Yang Valid (Untuk Kolom Kelas):');
        $sheet->getStyle('J1')->getFont()->setBold(true);
        $classrooms = Classroom::orderBy('nama')->get();
        $row = 2;
        foreach ($classrooms as $c) {
            $sheet->setCellValue('J' . $row, $c->nama);
            $row++;
        }

        // Auto size columns
        foreach (range(1, 11) as $colIndex) {
            $colLetter = \PhpOffice\PhpSpreadsheet\Cell\Coordinate::stringFromColumnIndex($colIndex);
            $sheet->getColumnDimension($colLetter)->setAutoSize(true);
        }

        $writer = new \PhpOffice\PhpSpreadsheet\Writer\Xlsx($spreadsheet);
        
        header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        header('Content-Disposition: attachment; filename="template_import_siswa.xlsx"');
        header('Cache-Control: max-age=0');
        
        $writer->save('php://output');
        exit;
    }

    public function import(Request $request)
    {
        $request->validate([
            'file' => 'required|file|mimes:xlsx,xls,csv|max:5120',
        ]);

        $file = $request->file('file');
        
        try {
            $spreadsheet = \PhpOffice\PhpSpreadsheet\IOFactory::load($file->getRealPath());
            $sheet = $spreadsheet->getActiveSheet();
            $rows = $sheet->toArray();
            
            if (count($rows) < 1) {
                return redirect()->back()->withErrors(['file' => 'File Excel kosong.']);
            }
            
            $classroomMap = Classroom::all()->pluck('id', 'nama')->toArray();
            
            $successCount = 0;
            $errorRows = [];
            
            for ($i = 1; $i < count($rows); $i++) {
                $rowData = $rows[$i];
                
                if (empty($rowData[0]) && empty($rowData[2])) {
                    continue;
                }
                
                $nis = isset($rowData[0]) ? trim($rowData[0]) : '';
                $nisn = isset($rowData[1]) ? trim($rowData[1]) : null;
                $nama = isset($rowData[2]) ? trim($rowData[2]) : '';
                $jk = isset($rowData[3]) ? strtoupper(trim($rowData[3])) : '';
                $className = isset($rowData[4]) ? trim($rowData[4]) : '';
                $alamat = isset($rowData[5]) ? trim($rowData[5]) : '';
                $hp = isset($rowData[6]) ? trim($rowData[6]) : '';
                $hpOrtu = isset($rowData[7]) ? trim($rowData[7]) : null;
                
                if (empty($nis)) {
                    $errorRows[] = "Baris " . ($i + 1) . ": NIS tidak boleh kosong.";
                    continue;
                }
                
                if (empty($nama)) {
                    $errorRows[] = "Baris " . ($i + 1) . ": Nama tidak boleh kosong.";
                    continue;
                }
                
                if ($jk !== 'L' && $jk !== 'P') {
                    $errorRows[] = "Baris " . ($i + 1) . ": Jenis kelamin harus L atau P.";
                    continue;
                }
                
                if (!isset($classroomMap[$className])) {
                    $errorRows[] = "Baris " . ($i + 1) . ": Kelas '" . $className . "' tidak ditemukan di database.";
                    continue;
                }
                
                $existing = Student::where('nis', $nis)->first();
                if ($existing) {
                    $existing->update([
                        'nisn' => $nisn,
                        'nama' => $nama,
                        'classroom_id' => $classroomMap[$className],
                        'kelas' => $className,
                        'jenis_kelamin' => $jk,
                        'alamat' => $alamat,
                        'hp' => $hp,
                        'hp_ortu' => $hpOrtu,
                    ]);
                    $successCount++;
                    continue;
                }
                
                Student::create([
                    'nis' => $nis,
                    'nisn' => $nisn,
                    'nama' => $nama,
                    'classroom_id' => $classroomMap[$className],
                    'kelas' => $className,
                    'jenis_kelamin' => $jk,
                    'alamat' => $alamat,
                    'hp' => $hp,
                    'hp_ortu' => $hpOrtu,
                ]);
                
                $successCount++;
            }
            
            if (count($errorRows) > 0) {
                $errorMsg = "Berhasil mengimpor " . $successCount . " siswa. Beberapa baris gagal:\n" . implode("\n", array_slice($errorRows, 0, 5));
                if (count($errorRows) > 5) {
                    $errorMsg .= "\n...dan " . (count($errorRows) - 5) . " kesalahan lainnya.";
                }
                return redirect()->back()->with('success', "Import selesai dengan beberapa catatan.")
                                             ->withErrors(['import_errors' => $errorMsg]);
            }
            
            return redirect()->back()->with('success', "Berhasil mengimpor {$successCount} siswa!");
            
        } catch (\Exception $e) {
            return redirect()->back()->withErrors(['file' => 'Gagal membaca file Excel: ' . $e->getMessage()]);
        }
    }
}
