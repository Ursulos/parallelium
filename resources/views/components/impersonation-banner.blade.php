@if (session('impersonating_admin_id'))
    <div class="fixed inset-x-0 top-0 z-50 flex items-center justify-center gap-3 bg-amber-500 px-4 py-2 text-center text-xs font-semibold text-amber-950">
        <span>
            Support Parallelium : vous naviguez en tant que <strong>{{ auth()->user()->name }}</strong>
            ({{ session('impersonating_admin_name') }} est connecté en administrateur)
        </span>
        <form method="POST" action="{{ route('impersonation.stop') }}">
            @csrf
            <button type="submit" class="rounded-full bg-amber-950/10 px-3 py-1 hover:bg-amber-950/20">
                Revenir à l'administration
            </button>
        </form>
    </div>
@endif
