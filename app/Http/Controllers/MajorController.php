<?php

namespace App\Http\Controllers;

use App\Models\Major;
use Illuminate\Http\Request;
use Inertia\Inertia;

class MajorController extends Controller
{
    public function index(Request $request)
    {
        $query = Major::query();

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('nama', 'like', "%{$search}%")
                  ->orWhere('kode', 'like', "%{$search}%");
            });
        }

        $majors = $query->latest()->paginate(10)->withQueryString();

        return Inertia::render('Jurusan/Index', [
            'majors' => $majors,
            'filters' => $request->only(['search']),
            'flash' => [
                'success' => session('success')
            ]
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:100',
            'kode' => 'required|string|max:20|unique:majors,kode',
        ]);

        Major::create($validated);

        return redirect()->back()->with('success', 'Jurusan berhasil ditambahkan!');
    }

    public function update(Request $request, Major $jurusan)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:100',
            'kode' => 'required|string|max:20|unique:majors,kode,' . $jurusan->id,
        ]);

        $jurusan->update($validated);

        return redirect()->back()->with('success', 'Jurusan berhasil diperbarui!');
    }

    public function destroy(Major $jurusan)
    {
        // Check if major is used by any classroom
        if ($jurusan->classrooms()->exists()) {
            return redirect()->back()->with('success', 'Gagal: Jurusan sedang digunakan oleh kelas!');
        }

        $jurusan->delete();

        return redirect()->back()->with('success', 'Jurusan berhasil dihapus!');
    }
}
