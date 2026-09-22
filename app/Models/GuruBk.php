<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GuruBk extends Model
{
    protected $table = 'guru_bks';

    protected $fillable = [
        'user_id',
        'nip',
        'nama',
        'jenis_kelamin',
        'no_hp',
        'email',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
