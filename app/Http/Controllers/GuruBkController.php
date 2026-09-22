<?php

namespace App\Http\Controllers;

use App\Models\GuruBk;
use App\Models\User;
use Illuminate\Http\Request;
use Inertia\Inertia;

class GuruBkController extends Controller
{
    public function index(Request $request)
    {
        $query = GuruBk::query();

        // Search Filter
        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function($q) use ($search) {
                $q->where('nama', 'like', "%{$search}%")
                  ->orWhere('nip', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        // Gender Filter
        if ($request->filled('jenis_kelamin')) {
            $query->where('jenis_kelamin', $request->input('jenis_kelamin'));
        }

        $guruBks = $query->latest()->paginate(10)->withQueryString();

        return Inertia::render('GuruBk/Index', [
            'guruBks' => $guruBks,
            'filters' => $request->only(['search', 'jenis_kelamin']),
            'flash' => [
                'success' => session('success')
            ]
        ]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'nama' => 'required|string|max:100',
            'nip' => 'nullable|string|max:30|unique:guru_bks,nip',
            'jenis_kelamin' => 'required|in:L,P',
            'no_hp' => 'nullable|string|max:20',
            'email' => 'nullable|required_if:create_account,true|email|max:100|unique:guru_bks,email|unique:users,email',
            'create_account' => 'boolean',
            'password' => 'required_if:create_account,true|nullable|string|min:8',
        ]);

        $userId = null;
        if ($request->input('create_account') && $request->filled('email')) {
            $user = User::create([
                'name' => $validated['nama'],
                'email' => $validated['email'],
                'password' => bcrypt($validated['password']),
            ]);
            $userId = $user->id;
        }

        GuruBk::create([
            'user_id' => $userId,
            'nip' => $validated['nip'],
            'nama' => $validated['nama'],
            'jenis_kelamin' => $validated['jenis_kelamin'],
            'no_hp' => $validated['no_hp'],
            'email' => $validated['email'],
        ]);

        return redirect()->back()->with('success', 'Guru BK berhasil ditambahkan!');
    }

    public function update(Request $request, GuruBk $guruBk)
    {
        $emailRule = $guruBk->user_id 
            ? 'required|email|max:100|unique:guru_bks,email,' . $guruBk->id . '|unique:users,email,' . $guruBk->user_id . ',id'
            : 'nullable|required_if:create_account,true|email|max:100|unique:guru_bks,email,' . $guruBk->id . '|unique:users,email,NULL,id';

        $validated = $request->validate([
            'nama' => 'required|string|max:100',
            'nip' => 'nullable|string|max:30|unique:guru_bks,nip,' . $guruBk->id,
            'jenis_kelamin' => 'required|in:L,P',
            'no_hp' => 'nullable|string|max:20',
            'email' => $emailRule,
            'create_account' => 'boolean',
            'password' => 'nullable|required_if:create_account,true|string|min:8',
        ]);

        if ($guruBk->user_id) {
            $user = User::find($guruBk->user_id);
            if ($user) {
                $userUpdate = [
                    'name' => $validated['nama'],
                ];
                if ($validated['email']) {
                    $userUpdate['email'] = $validated['email'];
                }
                if ($request->filled('password')) {
                    $userUpdate['password'] = bcrypt($validated['password']);
                }
                $user->update($userUpdate);
            }
        } elseif ($request->input('create_account') && $request->filled('email')) {
            $user = User::create([
                'name' => $validated['nama'],
                'email' => $validated['email'],
                'password' => bcrypt($request->input('password')),
            ]);
            $guruBk->user_id = $user->id;
        }

        $guruBk->update([
            'nip' => $validated['nip'],
            'nama' => $validated['nama'],
            'jenis_kelamin' => $validated['jenis_kelamin'],
            'no_hp' => $validated['no_hp'],
            'email' => $validated['email'],
            'user_id' => $guruBk->user_id,
        ]);

        return redirect()->back()->with('success', 'Guru BK berhasil diperbarui!');
    }

    public function destroy(GuruBk $guruBk)
    {
        if ($guruBk->user_id) {
            User::destroy($guruBk->user_id);
        } else {
            $guruBk->delete();
        }

        return redirect()->back()->with('success', 'Guru BK berhasil dihapus!');
    }
}
