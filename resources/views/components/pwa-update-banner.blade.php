<div
    x-data="{ show: false, registration: null }"
    x-on:parallelium-update-available.window="show = true; registration = $event.detail.registration"
    x-show="show"
    x-cloak
    x-transition
    class="fixed inset-x-0 bottom-20 z-40 mx-auto w-full max-w-sm px-4 lg:bottom-6">
    <div class="flex items-center gap-3 rounded-2xl bg-slate-900 px-4 py-3 text-white shadow-xl">
        <x-icon name="info" class="text-brand-300" />
        <p class="flex-1 text-sm">Nouvelle version disponible.</p>
        <button
            type="button"
            x-on:click="registration?.waiting?.postMessage('SKIP_WAITING'); show = false"
            class="shrink-0 rounded-lg bg-white/15 px-3 py-1.5 text-xs font-semibold hover:bg-white/25">
            Mettre à jour
        </button>
    </div>
</div>
