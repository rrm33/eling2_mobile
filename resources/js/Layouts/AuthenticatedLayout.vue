<script setup>
import { ref } from 'vue';
import ApplicationLogo from '@/Components/ApplicationLogo.vue';
import Dropdown from '@/Components/Dropdown.vue';
import DropdownLink from '@/Components/DropdownLink.vue';
import { Link, usePage } from '@inertiajs/vue3';

const isMobileSidebarOpen = ref(false);

const toggleMobileSidebar = () => {
    isMobileSidebarOpen.value = !isMobileSidebarOpen.value;
};

const page = usePage();
</script>

<template>
    <div class="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-100 flex transition-colors duration-300">
        
        <!-- SIDEBAR: Desktop Sidebar (Left Panel) -->
        <aside class="hidden lg:flex lg:flex-col lg:w-64 bg-slate-900 text-slate-300 border-r border-slate-800 shrink-0 sticky top-0 h-screen z-40">
            <!-- Sidebar Brand Header -->
            <div class="h-16 flex items-center gap-3 px-6 border-b border-slate-800 bg-slate-950/40">
                <div class="h-9 w-9 rounded-lg bg-gradient-to-br from-blue-500 to-sky-600 flex items-center justify-center text-white font-black shadow-md shadow-blue-500/20">
                    BK
                </div>
                <div>
                    <h2 class="text-sm font-extrabold text-white tracking-wide uppercase leading-tight">BK-SMKN 6 JEMBER</h2>
                    <span class="text-[10px] text-slate-500 dark:text-slate-400 font-semibold tracking-wider uppercase">Portal Admin BK</span>
                </div>
            </div>

            <!-- Sidebar Navigation Links -->
            <nav class="flex-1 px-4 py-6 space-y-1.5 overflow-y-auto">
                <Link 
                    :href="route('dashboard')"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('dashboard') 
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2v-4zM14 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2v-4z" />
                    </svg>
                    <span>Dashboard</span>
                </Link>

                <div class="pt-4 pb-2 px-4 text-[10px] font-black text-slate-500 uppercase tracking-widest">Layanan BK</div>

                <Link 
                    :href="route('siswa.index')"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('siswa.index') || route().current('siswa.show')
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                    <span>Data Siswa</span>
                </Link>

                <Link 
                    :href="route('kelas.index')"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('kelas.index')
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                    </svg>
                    <span>Data Kelas</span>
                </Link>

                <Link 
                    :href="route('jurusan.index')"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('jurusan.index')
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                    </svg>
                    <span>Data Jurusan</span>
                </Link>

                <Link 
                    :href="route('guru-bk.index')"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('guru-bk.index')
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                    <span>Data Guru BK</span>
                </Link>

                <Link 
                    :href="route('konseling.index')" 
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('konseling.index') 
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                    <span>Layanan Konseling</span>
                </Link>

                <Link 
                    href="#" 
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl text-slate-400 hover:bg-slate-800 hover:text-white transition duration-200"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span>Agenda Konseling</span>
                </Link>

                <div class="pt-4 pb-2 px-4 text-[10px] font-black text-slate-500 uppercase tracking-widest">Sistem & Fitur</div>

                <Link 
                    href="/design-system" 
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('design-system') 
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M11 4a2 2 0 114 0v1a2 2 0 002 2h3a2 2 0 110 4h-1a2 2 0 00-2 2v3a2 2 0 11-4 0v-1a2 2 0 00-2-2H7a2 2 0 110-4h1a2 2 0 002-2V7a2 2 0 114 0V4z" />
                    </svg>
                    <span>Design System</span>
                </Link>
            </nav>

            <!-- Sidebar User Profile Footer -->
            <div class="p-4 border-t border-slate-800 bg-slate-950/30 flex items-center justify-between gap-3">
                <div class="flex items-center gap-2 truncate">
                    <div class="h-9 w-9 rounded-lg bg-blue-500/15 border border-blue-500/20 text-blue-400 flex items-center justify-center font-bold font-mono">
                        {{ $page.props.auth.user.name.charAt(0) }}
                    </div>
                    <div class="truncate">
                        <div class="text-xs font-bold text-white truncate">{{ $page.props.auth.user.name }}</div>
                        <div class="text-[10px] text-slate-500 truncate">{{ $page.props.auth.user.email }}</div>
                    </div>
                </div>
            </div>
        </aside>

        <!-- MOBILE SIDEBAR: Drawer Slider Overlay -->
        <div v-if="isMobileSidebarOpen" class="fixed inset-0 bg-slate-950/60 backdrop-blur-xs z-50 lg:hidden" @click="toggleMobileSidebar"></div>
        <aside 
            class="fixed inset-y-0 left-0 w-64 bg-slate-900 text-slate-300 border-r border-slate-800 z-55 lg:hidden flex flex-col transform transition-transform duration-300 ease-in-out"
            :class="isMobileSidebarOpen ? 'translate-x-0' : '-translate-x-full'"
        >
            <div class="h-16 flex items-center justify-between px-6 border-b border-slate-800 bg-slate-950/40">
                <div class="flex items-center gap-3">
                    <div class="h-8 w-8 rounded-lg bg-gradient-to-br from-blue-500 to-sky-600 flex items-center justify-center text-white font-black shadow-xs">
                        BK
                    </div>
                    <span class="text-sm font-extrabold text-white tracking-wider uppercase">Portal BK</span>
                </div>
                <button @click="toggleMobileSidebar" class="p-1 text-slate-500 hover:text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>

            <!-- Mobile Navigation -->
            <nav class="flex-1 px-4 py-6 space-y-1.5 overflow-y-auto">
                <Link 
                    :href="route('dashboard')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('dashboard') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Dashboard</span>
                </Link>
                <Link 
                    :href="route('siswa.index')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('siswa.index') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Data Siswa</span>
                </Link>
                <Link 
                    :href="route('kelas.index')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('kelas.index') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Data Kelas</span>
                </Link>
                <Link 
                    :href="route('jurusan.index')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('jurusan.index') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Data Jurusan</span>
                </Link>
                <Link 
                    :href="route('guru-bk.index')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('guru-bk.index') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Data Guru BK</span>
                </Link>
                <Link 
                    :href="route('konseling.index')"
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('konseling.index') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Layanan Konseling</span>
                </Link>
                <Link 
                    href="#" 
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl text-slate-400 hover:bg-slate-800 hover:text-white transition duration-200"
                >
                    <span>Agenda Konseling</span>
                </Link>
                <Link 
                    href="/design-system" 
                    @click="isMobileSidebarOpen = false"
                    class="flex items-center gap-3 px-4 py-3 text-sm font-semibold rounded-xl transition duration-200"
                    :class="[
                        route().current('design-system') 
                            ? 'bg-blue-600 text-white shadow-md' 
                            : 'hover:bg-slate-800 hover:text-white text-slate-400'
                    ]"
                >
                    <span>Design System</span>
                </Link>
            </nav>
        </aside>

        <!-- MAIN LAYOUT AREA: Contains Navbar and Content Workspace -->
        <div class="flex-1 flex flex-col min-w-0 min-h-screen">
            
            <!-- TOP BAR (Navbar) -->
            <header class="h-16 border-b border-gray-200 dark:border-gray-800 bg-white/70 dark:bg-slate-900/70 backdrop-blur-md sticky top-0 z-30 flex items-center justify-between px-6 shadow-xs">
                <!-- Hamburger Button (Mobile Only) -->
                <button 
                    @click="toggleMobileSidebar" 
                    class="lg:hidden p-2 rounded-xl text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800 hover:text-slate-700 dark:hover:text-white transition duration-150"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
                    </svg>
                </button>

                <!-- Search Placeholder / Accents (Optional/Aesthetics) -->
                <div class="hidden md:flex items-center gap-2 text-xs font-semibold text-slate-400 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-200/50 dark:border-slate-700/50">
                    <span class="h-2 w-2 rounded-full bg-emerald-500 animate-pulse"></span>
                    <span>Admin Mode Aktif</span>
                </div>

                <!-- User settings dropdown & actions -->
                <div class="flex items-center gap-4">
                    <Dropdown align="right" width="48">
                        <template #trigger>
                            <span class="inline-flex rounded-md">
                                <button
                                    type="button"
                                    class="inline-flex items-center rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-slate-900 px-4 py-2 text-sm font-semibold text-slate-600 dark:text-slate-300 hover:text-blue-600 dark:hover:text-blue-400 hover:border-blue-100 dark:hover:border-blue-900 transition duration-150 focus:outline-none cursor-pointer"
                                >
                                    {{ $page.props.auth.user.name }}
                                    <svg
                                        class="-me-0.5 ms-2 h-4 w-4"
                                        xmlns="http://www.w3.org/2000/svg"
                                        viewBox="0 0 20 20"
                                        fill="currentColor"
                                    >
                                        <path
                                            fill-rule="evenodd"
                                            d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                                            clip-rule="evenodd"
                                        />
                                    </svg>
                                </button>
                            </span>
                        </template>

                        <template #content>
                            <DropdownLink :href="route('profile.edit')">
                                Profil Saya
                            </DropdownLink>
                            <DropdownLink :href="route('logout')" method="post" as="button">
                                Keluar (Log Out)
                            </DropdownLink>
                        </template>
                    </Dropdown>
                </div>
            </header>

            <!-- SUB-HEADER (Breadcrumbs/Page Titles) -->
            <div class="border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-slate-900 py-6" v-if="$slots.header">
                <div class="mx-auto max-w-7xl px-6 lg:px-8">
                    <slot name="header" />
                </div>
            </div>

            <!-- CORE WORKSPACE CONTENT -->
            <main class="flex-1 overflow-y-auto">
                <slot />
            </main>
        </div>

    </div>
</template>
