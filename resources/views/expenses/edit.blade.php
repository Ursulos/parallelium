<x-layouts.app title="Modifier la dépense">
    <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-900">Modifier la dépense</h2>
    </div>

    @if ($errors->any())
        <x-alert type="error" class="mb-4">
            <ul class="list-inside list-disc space-y-1">
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </x-alert>
    @endif

    <x-card>
        <form method="POST" action="{{ route('expenses.update', $expense) }}" enctype="multipart/form-data">
            @include('expenses._form')
        </form>
    </x-card>
</x-layouts.app>
