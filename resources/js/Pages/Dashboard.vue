<script setup>
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout.vue';
import { Head, Link } from '@inertiajs/vue3';
import Card from '@/Components/Card.vue';
import Table from '@/Components/Table.vue';
import Badge from '@/Components/Badge.vue';
import PrimaryButton from '@/Components/PrimaryButton.vue';
import SecondaryButton from '@/Components/SecondaryButton.vue';
import { ref } from 'vue';

// Stats Mock Data (will be dynamic in production)
const stats = ref({
    totalStudents: 154,
    activeCases: 8,
    resolvedCases: 112,
    todayAppointments: 4,
});

// Recent active cases
const recentCases = ref([
    { id: 1, name: 'Siti Aminah', class: 'XII RPL 2', category: 'karir', title: 'Kebingungan Memilih Jurusan Kuliah', status: 'Baru', badge: 'info', date: 'Hari ini, 08:30' },
    { id: 2, name: 'Rian Rizqi', class: 'XI TKJ 1', category: 'sosial', title: 'Keterlibatan Perselisihan di Kelas', status: 'Sedang Proses', badge: 'warning', date: 'Kemarin, 14:15' },
    { id: 3, name: 'Budi Santoso', class: 'X MM 3', category: 'pribadi', title: 'Kecemasan Menjelang Ujian Tengah Semester', status: 'Sedang Proses', badge: 'warning', date: '18 Mei 2026' },
    { id: 4, name: 'Lutfi Hakim', class: 'XII RPL 1', category: 'karir', title: 'Rencana Rujukan Beasiswa Industri', status: 'Selesai', badge: 'success', date: '17 Mei 2026' },
]);

// Upcoming appointments today
const upcomingAppointments = ref([
    { id: 1, name: 'Ahmad Fauzi', class: 'XI RPL 2', time: '09:30 WIB', type: 'Konseling Individu', topic: 'Masalah Kehadiran' },
    { id: 2, name: 'Dewi Lestari', class: 'XII MM 1', time: '11:00 WIB', type: 'Konseling Karir', topic: 'Persiapan Kerja/Magang' },
    { id: 3, name: 'Kelompok 4 (3 Siswa)', class: 'X TKJ 2', time: '13:30 WIB', type: 'Konseling Kelompok', topic: 'Kekompakan Kelas' },
]);

const getCategoryBadge = (cat) => {
    const types = {
        pribadi: 'bg-sky-100 text-sky-800 dark:bg-sky-950/40 dark:text-sky-300 border border-sky-200/50 dark:border-sky-900/50',
        sosial: 'bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-300 border border-blue-200/50 dark:border-blue-900/50',
        karir: 'bg-sky-100 text-sky-800 dark:bg-sky-950/40 dark:text-sky-300 border border-sky-200/50 dark:border-sky-900/50',
    };
    return types[cat] || 'bg-slate-100 text-slate-800';
};
</script>

<template>
    <Head title="Dashboard Guru BK" />

    <AuthenticatedLayout>
        <template #header>
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h2 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-700 via-blue-600 to-blue-500 bg-clip-text text-transparent dark:from-blue-400 dark:via-blue-400 dark:to-sky-400 leading-tight">
                        Dashboard Guru BK
                    </h2>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Selamat datang kembali! Mari bantu masa depan siswa kita hari ini.</p>
                </div>
                <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-slate-600 dark:text-slate-300 bg-white/80 dark:bg-gray-900/80 backdrop-blur-md px-4 py-2 rounded-xl border border-blue-100/50 dark:border-sky-900/50 shadow-sm">
                        ✨ Hari Ini: {{ new Date().toLocaleDateString('id-ID', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }) }}
                    </span>
                </div>
            </div>
        </template>

        <div class="py-8 relative overflow-hidden">
            <!-- Background colorful glowing orbs -->
            <div class="absolute top-20 left-1/4 w-96 h-96 bg-blue-500/10 dark:bg-blue-600/5 rounded-full filter blur-3xl mix-blend-multiply pointer-events-none"></div>
            <div class="absolute top-40 right-1/4 w-96 h-96 bg-sky-500/10 dark:bg-sky-600/5 rounded-full filter blur-3xl mix-blend-multiply pointer-events-none"></div>
            <div class="absolute bottom-20 left-1/3 w-96 h-96 bg-blue-500/10 dark:bg-blue-600/5 rounded-full filter blur-3xl mix-blend-multiply pointer-events-none"></div>

            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 space-y-8 relative z-10">
                
                <!-- Quick Stats Grid: Premium Colorful Gradients -->
                <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                    <!-- Stat Card 1: Indigo Gradient -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Total Siswa Binaan</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.totalStudents }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1 bg-white/10 px-2 py-1 rounded-md w-fit">
                            <span>↑ 12%</span>
                            <span class="text-blue-200/80 font-normal">dari bulan lalu</span>
                        </div>
                    </Card>

                    <!-- Stat Card 2: Purple Gradient -->
                    <Card variant="purple" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-sky-100/80 uppercase tracking-wider">Kasus Aktif</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.activeCases }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-sky-100 font-semibold gap-1 bg-white/10 px-2 py-1 rounded-md w-fit">
                            <span>⚠️ Butuh perhatian</span>
                            <span class="text-sky-200/80 font-normal">segera</span>
                        </div>
                    </Card>

                    <!-- Stat Card 3: Blue Gradient -->
                    <Card variant="blue" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Selesai Ditangani</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.resolvedCases }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1 bg-white/10 px-2 py-1 rounded-md w-fit">
                            <span>✨ Efektivitas 93%</span>
                        </div>
                    </Card>

                    <!-- Stat Card 4: Sky Blue Gradient -->
                    <Card variant="sky" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-sky-100/80 uppercase tracking-wider">Jadwal Hari Ini</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.todayAppointments }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-sky-100 font-semibold gap-1 bg-white/10 px-2 py-1 rounded-md w-fit">
                            <span>📅 Konseling aktif</span>
                        </div>
                    </Card>
                </div>

                <!-- Main Layout Columns -->
                <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
                    <!-- Column 1: Active Cases (Left/Larger) -->
                    <div class="lg:col-span-2 space-y-6">
                        <Card variant="glass" class="border-t-4 border-t-blue-500">
                            <template #header>
                                <div class="flex items-center justify-between">
                                    <div>
                                        <h3 class="text-lg font-bold text-slate-900 dark:text-white">Kasus Aktif Terbaru</h3>
                                        <p class="text-xs text-slate-500">Antrean bimbingan konseling yang membutuhkan respon & tindak lanjut.</p>
                                    </div>
                                    <Link href="/design-system" class="text-xs font-bold text-blue-600 dark:text-blue-400 hover:text-sky-500 transition duration-150">
                                        Lihat Semua Kasus →
                                    </Link>
                                </div>
                            </template>

                            <Table :headers="['Nama Siswa', 'Kelas', 'Kategori', 'Detail Permasalahan', 'Status', 'Aksi']">
                                <tr 
                                    v-for="c in recentCases" 
                                    :key="c.id"
                                    class="hover:bg-blue-50/20 dark:hover:bg-blue-950/10 transition duration-150"
                                >
                                    <td class="px-6 py-4 font-semibold text-slate-900 dark:text-white">
                                        <div>
                                            <span>{{ c.name }}</span>
                                            <span class="block text-[10px] text-slate-400 font-normal mt-0.5">{{ c.date }}</span>
                                        </div>
                                    </td>
                                    <td class="px-6 py-4 text-xs font-semibold">{{ c.class }}</td>
                                    <td class="px-6 py-4">
                                        <span class="capitalize text-[10px] font-bold px-2.5 py-1 rounded-full shadow-xs" :class="getCategoryBadge(c.category)">
                                            {{ c.category }}
                                        </span>
                                    </td>
                                    <td class="px-6 py-4 max-w-[200px] truncate text-xs text-slate-600 dark:text-slate-400 font-medium" :title="c.title">
                                        {{ c.title }}
                                    </td>
                                    <td class="px-6 py-4">
                                        <Badge :type="c.badge">{{ c.status }}</Badge>
                                    </td>
                                    <td class="px-6 py-4">
                                        <PrimaryButton class="!py-1 !px-3 !text-[11px] font-bold bg-gradient-to-r from-blue-500 to-sky-600 border-none hover:from-blue-600 hover:to-sky-700 shadow-sm shadow-blue-500/10 transition-transform active:scale-95">
                                            Buka Sesi
                                        </PrimaryButton>
                                    </td>
                                </tr>
                            </Table>
                        </Card>
                    </div>

                    <!-- Column 2: Today's Appointments (Right/Smaller) -->
                    <div class="space-y-6">
                        <Card variant="glass" class="border-t-4 border-t-sky-500">
                            <template #header>
                                <div class="flex items-center justify-between">
                                    <div>
                                        <h3 class="text-lg font-bold text-slate-900 dark:text-white">Agenda Hari Ini</h3>
                                        <p class="text-xs text-slate-500">Jadwal konsultasi bimbingan.</p>
                                    </div>
                                    <Badge type="primary" class="!bg-sky-100 !text-sky-800 dark:!bg-sky-950/60 dark:!text-sky-300">
                                        {{ upcomingAppointments.length }} Sesi
                                    </Badge>
                                </div>
                            </template>

                            <!-- Appointments List -->
                            <div class="space-y-4">
                                <div 
                                    v-for="app in upcomingAppointments" 
                                    :key="app.id"
                                    class="p-4 rounded-xl border border-gray-100 dark:border-gray-800 bg-slate-50/50 dark:bg-slate-900/30 hover:shadow-md hover:border-blue-100 dark:hover:border-blue-900/50 transition-all duration-300"
                                >
                                    <div class="flex justify-between items-start gap-2">
                                        <div>
                                            <h4 class="font-bold text-sm text-slate-900 dark:text-white">{{ app.name }}</h4>
                                            <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">{{ app.class }} • <span class="font-bold text-sky-600 dark:text-sky-400">{{ app.type }}</span></p>
                                        </div>
                                        <span class="text-xs font-black bg-blue-50 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300 py-1 px-2.5 rounded-lg border border-blue-100/50 dark:border-blue-900/50 shadow-xs">
                                            {{ app.time }}
                                        </span>
                                    </div>
                                    
                                    <div class="mt-3 pt-3 border-t border-gray-150 dark:border-gray-800/80 flex items-center justify-between gap-4">
                                        <span class="text-xs text-slate-600 dark:text-slate-400 italic truncate max-w-[170px]" :title="app.topic">
                                            "{{ app.topic }}"
                                        </span>
                                        <SecondaryButton class="!py-1 !px-3 !text-[10px] font-bold border-blue-200 dark:border-blue-800 hover:bg-blue-50 dark:hover:bg-blue-950/50 transition duration-150">
                                            Mulai
                                        </SecondaryButton>
                                    </div>
                                </div>

                                <div v-if="upcomingAppointments.length === 0" class="text-center py-6 text-slate-400 text-xs">
                                    Tidak ada jadwal konsultasi hari ini.
                                </div>
                            </div>
                        </Card>
                    </div>
                </div>

            </div>
        </div>
    </AuthenticatedLayout>
</template>

