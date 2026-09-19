<div
    x-data="pwaInstallBanner()"
    x-init="init()"
    x-show="visible"
    x-cloak
    x-transition
    class="fixed inset-x-0 bottom-20 z-40 mx-auto w-full max-w-sm px-4 lg:bottom-6">
    <div class="flex items-center gap-3 rounded-2xl border border-slate-100 bg-white px-4 py-3 shadow-xl">
        <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-brand-gradient text-sm text-white">
            <x-icon name="logo" />
        </span>
        <div class="min-w-0 flex-1">
            <p class="text-sm font-semibold text-slate-800">Installer Parallelium</p>
            <p class="text-xs text-slate-500" x-text="isIos ? 'Partager puis « Sur l’écran d’accueil »' : 'Accès rapide, comme une vraie application'"></p>
        </div>
        <button type="button" x-show="!isIos" x-on:click="install()" class="shrink-0 rounded-lg bg-brand-gradient px-3 py-1.5 text-xs font-semibold text-white">
            Installer
        </button>
        <button type="button" x-on:click="dismiss()" class="shrink-0 text-slate-300 hover:text-slate-500">
            <x-icon name="error" class="text-sm" />
        </button>
    </div>
</div>

<script>
    function pwaInstallBanner() {
        return {
            visible: false,
            isIos: false,
            deferredPrompt: null,

            init() {
                if (localStorage.getItem('parallelium-install-dismissed') === '1') return;

                // L'application est déjà installée (mode standalone) : rien à faire.
                if (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone) return;

                this.isIos = /iphone|ipad|ipod/i.test(window.navigator.userAgent) && !window.MSStream;

                if (this.isIos) {
                    // Safari iOS ne déclenche jamais beforeinstallprompt : on
                    // affiche l'astuce manuelle directement.
                    this.visible = true;
                    return;
                }

                window.addEventListener('beforeinstallprompt', (event) => {
                    event.preventDefault();
                    this.deferredPrompt = event;
                    this.visible = true;
                });
            },

            async install() {
                if (!this.deferredPrompt) { this.visible = false; return; }
                this.deferredPrompt.prompt();
                await this.deferredPrompt.userChoice;
                this.deferredPrompt = null;
                this.visible = false;
            },

            dismiss() {
                this.visible = false;
                localStorage.setItem('parallelium-install-dismissed', '1');
            },
        };
    }
</script>
