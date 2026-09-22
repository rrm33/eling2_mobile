<?php

namespace App\Http\Controllers;

use App\Models\Classroom;
use App\Models\Major;
use Illuminate\Http\Request;
use Inertia\Inertia;

class ClassroomController extends Controller
{
    public function index(Request $request)
    {
        $query = Classroom::with('major');

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where('nama', 'like', "%{$search}%")
                  ->orWhereHas('major', function($q) use ($search) {
                      $q->where('nama', 'like', "%{$search}%")
                        ->orWhere('kode', 'like', "%{$search}%");
                  });
        }

        $classrooms = $query->latest()->paginate(10)->withQueryString();
        $majors = Major::orderBy('nama')->get();

        return Inertia::render('Kelas/Index', [
            'classrooms' => $classrooms,
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
            'nama' => 'required|string|max:50|unique:classrooms,nama',
            'major_id' => 'required|exists:majors,id',
        ]);

        Classroom::create($validated);

        return redirect()->back()->with('success', 'Kelas berhasil ditambahkan!');
    }

    public function update(Request $request, Classroom $kela)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:50|unique:classrooms,nama,' . $kela->id,
            'major_id' => 'required|exists:majors,id',
        ]);

        $kela->update($validated);

        return redirect()->back()->with('success', 'Kelas berhasil diperbarui!');
    }

    public function destroy(Classroom $kela)
    {
        // Dissociate students from this classroom
        $kela->students()->update([
            'classroom_id' => null,
            'kelas' => ''
        ]);

        $kela->delete();

        return redirect()->back()->with('success', 'Kelas berhasil dihapus!');
    }
}
