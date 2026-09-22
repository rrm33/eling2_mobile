<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Student extends Model
{
    use HasFactory;

    protected $fillable = [
        'nis',
        'nisn',
        'nama',
        'kelas',
        'classroom_id',
        'jenis_kelamin',
        'alamat',
        'hp',
        'hp_ortu',
    ];

    public function classroom()
    {
        return $this->belongsTo(Classroom::class);
    }
}
