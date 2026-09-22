<?php

use App\Http\Controllers\ProfileController;
use App\Http\Controllers\StudentController;
use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::get('/', function () {
    return Inertia::render('Welcome', [
        'canLogin' => Route::has('login'),
        'canRegister' => Route::has('register'),
        'laravelVersion' => Application::VERSION,
        'phpVersion' => PHP_VERSION,
    ]);
});

Route::get('/dashboard', function () {
    return Inertia::render('Dashboard');
})->middleware(['auth', 'verified'])->name('dashboard');

Route::middleware('auth')->group(function () {
    Route::get('/profile', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::delete('/profile', [ProfileController::class, 'destroy'])->name('profile.destroy');
    
    // Student CRUD Resource & Import
    Route::get('siswa/download-template', [StudentController::class, 'downloadTemplate'])->name('siswa.download-template');
    Route::post('siswa/import', [StudentController::class, 'import'])->name('siswa.import');
    Route::resource('siswa', StudentController::class);

    // Jurusan & Kelas CRUD Resources
    Route::resource('jurusan', \App\Http\Controllers\MajorController::class);
    Route::resource('kelas', \App\Http\Controllers\ClassroomController::class);

    // Guru BK CRUD Resource
    Route::resource('guru-bk', \App\Http\Controllers\GuruBkController::class);

    // Counseling CRUD Resource
    Route::resource('konseling', \App\Http\Controllers\CounselingController::class);

    // Design System Route
    Route::get('/design-system', function () {
        return Inertia::render('DesignSystem');
    })->name('design-system');
});

require __DIR__.'/auth.php';
