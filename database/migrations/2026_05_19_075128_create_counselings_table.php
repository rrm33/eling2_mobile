<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('counselings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('students')->onDelete('cascade');
            $table->foreignId('guru_bk_id')->constrained('guru_bks')->onDelete('cascade');
            $table->date('tanggal');
            $table->string('jenis_layanan', 50); // Pribadi, Sosial, Belajar, Karir
            $table->text('masalah');
            $table->text('solusi')->nullable();
            $table->string('status', 20)->default('Selesai'); // Proses, Selesai, Rujukan
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('counselings');
    }
};
