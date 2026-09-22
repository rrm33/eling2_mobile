<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Student;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Avoid duplicate user seeding if it already exists
        if (!User::where('email', 'test@example.com')->exists()) {
            User::factory()->create([
                'name' => 'Guru BK SMKN 6 Jember',
                'email' => 'test@example.com',
                'password' => bcrypt('password'), // standard password
            ]);
        }

        // Seed Majors (Jurusan)
        $rpl = \App\Models\Major::firstOrCreate(['kode' => 'RPL'], ['nama' => 'Rekayasa Perangkat Lunak']);
        $tkj = \App\Models\Major::firstOrCreate(['kode' => 'TKJ'], ['nama' => 'Teknik Komputer & Jaringan']);
        $dkv = \App\Models\Major::firstOrCreate(['kode' => 'DKV'], ['nama' => 'Desain Komunikasi Visual']);

        // Seed Classrooms (Kelas)
        $classesMap = [
            'XII RPL 1' => \App\Models\Classroom::firstOrCreate(['nama' => 'XII RPL 1', 'major_id' => $rpl->id]),
            'XII RPL 2' => \App\Models\Classroom::firstOrCreate(['nama' => 'XII RPL 2', 'major_id' => $rpl->id]),
            'XI RPL 2'  => \App\Models\Classroom::firstOrCreate(['nama' => 'XI RPL 2', 'major_id' => $rpl->id]),
            'XI TKJ 1'  => \App\Models\Classroom::firstOrCreate(['nama' => 'XI TKJ 1', 'major_id' => $tkj->id]),
            'X DKV 3'   => \App\Models\Classroom::firstOrCreate(['nama' => 'X DKV 3', 'major_id' => $dkv->id]),
        ];

        // Seed Students
        $students = [
            [
                'nis' => '24250101',
                'nisn' => '0081234567',
                'nama' => 'Siti Aminah',
                'kelas' => 'XII RPL 2',
                'jenis_kelamin' => 'P',
                'alamat' => 'Jl. Merdeka No. 12, Kota Bandung',
                'hp' => '081234567890',
                'hp_ortu' => '089876543210',
            ],
            [
                'nis' => '24250102',
                'nisn' => '0092345678',
                'nama' => 'Rian Rizqi',
                'kelas' => 'XI TKJ 1',
                'jenis_kelamin' => 'L',
                'alamat' => 'Perum Cempaka Indah Blok C5, Kabupaten Bandung',
                'hp' => '082345678901',
                'hp_ortu' => '087765432109',
            ],
            [
                'nis' => '24250103',
                'nisn' => '0103456789',
                'nama' => 'Budi Santoso',
                'kelas' => 'X DKV 3',
                'jenis_kelamin' => 'L',
                'alamat' => 'Gang Masjid No. 45, Coblong, Kota Bandung',
                'hp' => '083456789012',
                'hp_ortu' => '085543210987',
            ],
            [
                'nis' => '24250104',
                'nisn' => '0084567890',
                'nama' => 'Lutfi Hakim',
                'kelas' => 'XII RPL 1',
                'jenis_kelamin' => 'L',
                'alamat' => 'Jl. Dago Giri No. 89, Lembang',
                'hp' => '085678901234',
                'hp_ortu' => '081298765432',
            ],
            [
                'nis' => '24250105',
                'nisn' => '0085678901',
                'nama' => 'Dewi Lestari',
                'kelas' => 'XII RPL 2',
                'jenis_kelamin' => 'P',
                'alamat' => 'Jl. Kiara Condong No. 102, Kota Bandung',
                'hp' => '087789012345',
                'hp_ortu' => '089987654321',
            ],
            [
                'nis' => '24250106',
                'nisn' => '0096789012',
                'nama' => 'Ahmad Fauzi',
                'kelas' => 'XI RPL 2',
                'jenis_kelamin' => 'L',
                'alamat' => 'Jl. Pahlawan Gg. Subur No. 15, Kota Bandung',
                'hp' => '089901234567',
                'hp_ortu' => '081234987654',
            ]
        ];

        foreach ($students as $student) {
            $classroom = $classesMap[$student['kelas']] ?? null;
            $student['classroom_id'] = $classroom ? $classroom->id : null;
            Student::firstOrCreate(['nis' => $student['nis']], $student);
        }
    }
}
