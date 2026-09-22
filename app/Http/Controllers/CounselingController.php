<?php

namespace App\Http\Controllers;

use App\Models\Counseling;
use App\Models\Student;
use App\Models\GuruBk;
use App\Models\Classroom;
use Illuminate\Http\Request;
use Inertia\Inertia;

class CounselingController extends Controller
{
    public function index(Request $request)
    {
        $query = Counseling::with(['student.classroom.major', 'guruBk']);

        // Search Filter (by student name or teacher name)
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->whereHas('student', function($sq) use ($search) {
                    $sq->where('nama', 'like', "%{$search}%")
                      ->orWhere('nis', 'like', "%{$search}%");
                })->orWhereHas('guruBk', function($tq) use ($search) {
                    $tq->where('nama', 'like', "%{$search}%");
                })->orWhere('masalah', 'like', "%{$search}%");
            });
        }

        // Service Type Filter
        if ($request->filled('jenis_layanan')) {
            $query->where('jenis_layanan', $request->input('jenis_layanan'));
        }

        // Status Filter
        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        // Date Filter
        if ($request->filled('tanggal')) {
            $query->whereDate('tanggal', $request->input('tanggal'));
        }

        $counselings = $query->latest()->paginate(10)->withQueryString();
        
        $students = Student::with('classroom')->orderBy('nama')->get();
        $teachers = GuruBk::orderBy('nama')->get();
        $classrooms = Classroom::with('major')->orderBy('nama')->get();

        return Inertia::render('Counseling/Index', [
            'counselings' => $counselings,
            'students' => $students,
            'teachers' => $teachers,
            'classrooms' => $classrooms,
            'filters' => $request->only(['search', 'jenis_layanan', 'status', 'tanggal']),
            'flash' => [
                'success' => session('success')
            ]
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'student_id' => 'required|exists:students,id',
            'guru_bk_id' => 'required|exists:guru_bks,id',
            'tanggal' => 'required|date',
            'jenis_layanan' => 'required|string|in:Pribadi,Sosial,Belajar,Karir',
            'masalah' => 'required|string',
            'solusi' => 'nullable|string',
            'status' => 'required|string|in:Proses,Selesai,Rujukan',
        ]);

        Counseling::create($validated);

        return redirect()->back()->with('success', 'Catatan konseling berhasil ditambahkan!');
    }

    public function update(Request $request, Counseling $konseling)
    {
        $validated = $request->validate([
            'student_id' => 'required|exists:students,id',
            'guru_bk_id' => 'required|exists:guru_bks,id',
            'tanggal' => 'required|date',
            'jenis_layanan' => 'required|string|in:Pribadi,Sosial,Belajar,Karir',
            'masalah' => 'required|string',
            'solusi' => 'nullable|string',
            'status' => 'required|string|in:Proses,Selesai,Rujukan',
        ]);

        $konseling->update($validated);

        return redirect()->back()->with('success', 'Catatan konseling berhasil diperbarui!');
    }

    public function destroy(Counseling $konseling)
    {
        $konseling->delete();

        return redirect()->back()->with('success', 'Catatan konseling berhasil dihapus!');
    }
}
