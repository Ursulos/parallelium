<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminUserController extends Controller
{
    public function index()
    {
        $admins = Admin::orderBy('name')->paginate(20);

        return view('admin.admins.index', compact('admins'));
    }

    public function create()
    {
        return view('admin.admins.create');
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:admins,email'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ]);

        Admin::create($data);

        return redirect()->route('admin.admins.index')->with('status', 'Administrateur ajouté.');
    }

    public function destroy(Request $request, Admin $admin)
    {
        if ($admin->id === $request->user('admin')->id) {
            return back()->withErrors(['admin' => 'Vous ne pouvez pas supprimer votre propre compte.']);
        }

        if (Admin::count() <= 1) {
            return back()->withErrors(['admin' => 'Impossible de supprimer le dernier compte administrateur.']);
        }

        $admin->delete();

        return back()->with('status', 'Administrateur supprimé.');
    }
}
