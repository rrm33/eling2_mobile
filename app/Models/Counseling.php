<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Counseling extends Model
{
    protected $table = 'counselings';

    protected $fillable = [
        'student_id',
        'guru_bk_id',
        'tanggal',
        'jenis_layanan',
        'masalah',
        'solusi',
        'status',
    ];

    public function student()
    {
        return $this->belongsTo(Student::class);
    }

    public function guruBk()
    {
        return $this->belongsTo(GuruBk::class);
    }
}
