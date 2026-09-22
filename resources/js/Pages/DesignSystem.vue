<script setup>
import { Head, Link } from '@inertiajs/vue3';
import { ref } from 'vue';
import Card from '@/Components/Card.vue';
import Table from '@/Components/Table.vue';
import Badge from '@/Components/Badge.vue';
import PrimaryButton from '@/Components/PrimaryButton.vue';
import SecondaryButton from '@/Components/SecondaryButton.vue';
import DangerButton from '@/Components/DangerButton.vue';
import TextInput from '@/Components/TextInput.vue';
import TextareaInput from '@/Components/TextareaInput.vue';
import SelectInput from '@/Components/SelectInput.vue';
import Checkbox from '@/Components/Checkbox.vue';
import InputLabel from '@/Components/InputLabel.vue';
import InputError from '@/Components/InputError.vue';

// Active Tab
const activeTab = ref('all');

// Form States
const textVal = ref('');
const textareaVal = ref('');
const selectVal = ref('');
const checkboxVal = ref(false);

const sampleOptions = [
    { value: 'pribadi', label: 'Pribadi (Masalah Emosi/Mental)' },
    { value: 'sosial', label: 'Sosial (Pertemanan/Keluarga)' },
    { value: 'karir', label: 'Karir & Akademik (Belajar/Lanjutan)' },
];

const sampleStudents = [
    { name: 'Ahmad Nur Cahyo', class: 'XII RPL 1', type: 'karir', case: 'Konsultasi Minat Bakat Kuliah', status: 'Selesai', badge: 'success' },
    { name: 'Siti Rahmawati', class: 'XI TKJ 3', type: 'pribadi', case: 'Mengalami Demotivasi Belajar', status: 'Sedang Proses', badge: 'warning' },
    { name: 'Rian Rizqi', class: 'XII RPL 2', type: 'sosial', case: 'Perselisihan Antar Teman Sekelas', status: 'Rujukan', badge: 'danger' },
    { name: 'Diana Lestari', class: 'X MM 2', type: 'pribadi', case: 'Kecemasan Menjelang Ujian', status: 'Baru', badge: 'info' }
];
</script>

<template>
    <Head title="Design System - BK" />

    <div class="min-h-screen bg-slate-50 text-slate-800 dark:bg-slate-950 dark:text-slate-200 transition-colors duration-300">
        <!-- Floating Glassmorphic Header -->
        <header class="sticky top-0 z-50 border-b border-gray-200/50 bg-white/70 backdrop-blur-md dark:border-gray-800/50 dark:bg-slate-900/70 py-4 shadow-xs">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row justify-between items-center gap-4">
                <div class="flex items-center gap-3">
                    <div class="h-10 w-10 rounded-xl bg-gradient-to-br from-blue-500 to-sky-600 flex items-center justify-center text-white font-black shadow-md shadow-blue-500/20">
                        BK
                    </div>
                    <div>
                        <h1 class="text-xl font-bold tracking-tight bg-gradient-to-r from-blue-600 to-sky-600 bg-clip-text text-transparent dark:from-blue-400 dark:to-sky-400">
                            Bimbingan Konseling UI Showcase
                        </h1>
                        <p class="text-xs text-slate-500 dark:text-slate-400">Desain Sistem & Galeri Komponen Konsisten</p>
                    </div>
                </div>
                
                <div class="flex items-center gap-2">
                    <Link href="/" class="text-sm font-medium text-slate-600 hover:text-blue-600 dark:text-slate-300 dark:hover:text-blue-400 transition">
                        Kembali ke Home
                    </Link>
                </div>
            </div>
        </header>

        <!-- Main Workspace -->
        <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
            <!-- Tabs Menu -->
            <div class="flex flex-wrap gap-2 mb-10 border-b border-gray-200 dark:border-gray-800 pb-5">
                <button 
                    v-for="tab in ['all', 'cards', 'buttons', 'forms', 'tables']" 
                    :key="tab"
                    @click="activeTab = tab"
                    class="px-4 py-2 text-sm font-medium rounded-lg capitalize transition duration-200 select-none cursor-pointer"
                    :class="[
                        activeTab === tab 
                            ? 'bg-blue-600 text-white shadow-md shadow-blue-600/10' 
                            : 'bg-white hover:bg-slate-100 text-slate-600 dark:bg-slate-900 dark:hover:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-800'
                    ]"
                >
                    {{ tab === 'all' ? 'Tampilkan Semua' : tab }}
                </button>
            </div>

            <!-- Tab Content: Cards -->
            <section v-if="activeTab === 'all' || activeTab === 'cards'" class="mb-12">
                <div class="flex items-center gap-3 mb-6">
                    <span class="h-8 w-1 bg-blue-600 dark:bg-blue-400 rounded-full"></span>
                    <h2 class="text-2xl font-extrabold tracking-tight">Kategori 1: Panel & Kartu (Cards)</h2>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                    <Card hoverable>
                        <template #header>
                            <h4 class="font-bold text-slate-900 dark:text-white">Default Card</h4>
                        </template>
                        <p class="text-sm text-slate-600 dark:text-slate-400">
                            Ini adalah kartu default dengan bayangan lembut dan border tipis. Cocok untuk wadah konten umum.
                        </p>
                        <template #footer>
                            <span class="text-xs text-slate-400">Card Footer</span>
                        </template>
                    </Card>

                    <Card variant="glass" hoverable>
                        <template #header>
                            <h4 class="font-bold text-slate-900 dark:text-white">Glassmorphism Card</h4>
                        </template>
                        <p class="text-sm text-slate-600 dark:text-slate-400">
                            Efek blur di belakang kartu memberikan kesan premium, modern, dan sangat dinamis pada antarmuka.
                        </p>
                    </Card>

                    <Card variant="primary" hoverable>
                        <template #header>
                            <h4 class="font-bold text-blue-700 dark:text-blue-400">Primary/Highlight Card</h4>
                        </template>
                        <p class="text-sm text-slate-600 dark:text-slate-400">
                            Memiliki background bernuansa biru-indigo tipis. Sempurna untuk menyoroti info penting atau notifikasi.
                        </p>
                    </Card>

                    <Card variant="gradient" hoverable>
                        <template #header>
                            <h4 class="font-bold text-sky-700 dark:text-sky-400">Gradient Border Card</h4>
                        </template>
                        <p class="text-sm text-slate-600 dark:text-slate-400">
                            Menggunakan latar belakang bergradasi ungu-indigo tipis yang futuristik. Sangat menawan untuk visual awal!
                        </p>
                    </Card>
                </div>
            </section>

            <!-- Tab Content: Buttons & Badges -->
            <section v-if="activeTab === 'all' || activeTab === 'buttons'" class="mb-12">
                <div class="flex items-center gap-3 mb-6">
                    <span class="h-8 w-1 bg-blue-600 dark:bg-blue-400 rounded-full"></span>
                    <h2 class="text-2xl font-extrabold tracking-tight">Kategori 2: Tombol & Label (Buttons & Badges)</h2>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <!-- Buttons Card -->
                    <Card>
                        <template #header>
                            <h4 class="font-bold text-slate-900 dark:text-white">Gaya Tombol (Button Styles)</h4>
                        </template>
                        <div class="flex flex-wrap gap-4 items-center">
                            <div class="flex flex-col gap-2">
                                <span class="text-xs text-slate-400 font-mono">PrimaryButton</span>
                                <PrimaryButton>Simpan Data</PrimaryButton>
                            </div>
                            <div class="flex flex-col gap-2">
                                <span class="text-xs text-slate-400 font-mono">SecondaryButton</span>
                                <SecondaryButton>Batal</SecondaryButton>
                            </div>
                            <div class="flex flex-col gap-2">
                                <span class="text-xs text-slate-400 font-mono">DangerButton</span>
                                <DangerButton>Hapus Kasus</DangerButton>
                            </div>
                        </div>
                    </Card>

                    <!-- Badges Card -->
                    <Card>
                        <template #header>
                            <h4 class="font-bold text-slate-900 dark:text-white">Label Status (Badges)</h4>
                        </template>
                        <p class="text-sm text-slate-500 mb-4">Mempunyai kontras warna yang ramah mata untuk status bimbingan konseling:</p>
                        <div class="flex flex-wrap gap-3">
                            <Badge type="primary">Primary</Badge>
                            <Badge type="success">Selesai (Success)</Badge>
                            <Badge type="warning">Sedang Proses (Warning)</Badge>
                            <Badge type="danger">Rujukan (Danger)</Badge>
                            <Badge type="info">Info Baru (Info)</Badge>
                            <Badge type="neutral">Arsip (Neutral)</Badge>
                        </div>
                    </Card>
                </div>
            </section>

            <!-- Tab Content: Form Inputs -->
            <section v-if="activeTab === 'all' || activeTab === 'forms'" class="mb-12">
                <div class="flex items-center gap-3 mb-6">
                    <span class="h-8 w-1 bg-blue-600 dark:bg-blue-400 rounded-full"></span>
                    <h2 class="text-2xl font-extrabold tracking-tight">Kategori 3: Pengisian Data (Form Inputs)</h2>
                </div>

                <Card>
                    <template #header>
                        <h4 class="font-bold text-slate-900 dark:text-white">Interaktivitas Formulir</h4>
                    </template>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                        <!-- Inputs Column -->
                        <div class="space-y-6">
                            <div>
                                <InputLabel for="text-input" value="Nama Lengkap Siswa" />
                                <TextInput 
                                    id="text-input" 
                                    v-model="textVal" 
                                    placeholder="Masukkan nama lengkap..." 
                                    class="mt-1 w-full"
                                />
                                <p class="text-xs text-slate-400 mt-1">Status Real-time: <span class="text-blue-600 dark:text-blue-400 font-medium">{{ textVal || 'Kosong' }}</span></p>
                            </div>

                            <div>
                                <InputLabel for="select-input" value="Kategori Kasus Bimbingan" />
                                <SelectInput 
                                    id="select-input" 
                                    v-model="selectVal" 
                                    :options="sampleOptions" 
                                    placeholder="Pilih kategori bimbingan..."
                                    class="mt-1"
                                />
                                <p class="text-xs text-slate-400 mt-1">Terpilih: <span class="text-blue-600 dark:text-blue-400 font-medium">{{ selectVal || 'Belum dipilih' }}</span></p>
                            </div>

                            <div class="flex items-center gap-2">
                                <Checkbox id="check-input" v-model:checked="checkboxVal" />
                                <InputLabel for="check-input" value="Siswa bersedia merahasiakan bimbingan ini" />
                            </div>
                        </div>

                        <!-- Textarea Column -->
                        <div class="space-y-6 flex flex-col justify-between">
                            <div>
                                <InputLabel for="textarea-input" value="Deskripsi Kasus & Catatan Konseling" />
                                <TextareaInput 
                                    id="textarea-input" 
                                    v-model="textareaVal" 
                                    placeholder="Tulis deskripsi permasalahan siswa dan langkah tindak lanjut di sini..." 
                                    class="mt-1"
                                />
                                <p class="text-xs text-slate-400 mt-1">Panjang Karakter: <span class="text-blue-600 dark:text-blue-400 font-medium">{{ textareaVal.length }} karakter</span></p>
                            </div>

                            <div class="bg-slate-100 dark:bg-slate-800/40 p-4 rounded-xl border border-dashed border-gray-300 dark:border-gray-700 text-sm text-slate-500">
                                ✨ <strong>Keterangan:</strong> Seluruh input form di atas didesain dengan garis fokus indigo yang menawan, transisi border, dan dukungan Dark Mode bawaan secara otomatis.
                            </div>
                        </div>
                    </div>
                </Card>
            </section>

            <!-- Tab Content: Data Tables -->
            <section v-if="activeTab === 'all' || activeTab === 'tables'" class="mb-12">
                <div class="flex items-center gap-3 mb-6">
                    <span class="h-8 w-1 bg-blue-600 dark:bg-blue-400 rounded-full"></span>
                    <h2 class="text-2xl font-extrabold tracking-tight">Kategori 4: Tabel Data Riwayat (Data Tables)</h2>
                </div>

                <div class="space-y-4">
                    <Table :headers="['Nama Siswa', 'Kelas', 'Kategori', 'Detail Permasalahan', 'Status Layanan', 'Aksi']">
                        <tr 
                            v-for="(student, idx) in sampleStudents" 
                            :key="idx"
                            class="hover:bg-slate-50/50 dark:hover:bg-slate-850/40 transition duration-150"
                        >
                            <td class="px-6 py-4 font-semibold text-slate-900 dark:text-white">{{ student.name }}</td>
                            <td class="px-6 py-4">{{ student.class }}</td>
                            <td class="px-6 py-4">
                                <span class="capitalize text-xs font-semibold px-2 py-1 rounded bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-350 border border-slate-200/50 dark:border-slate-700/50">
                                    {{ student.type }}
                                </span>
                            </td>
                            <td class="px-6 py-4 max-w-[250px] truncate text-slate-600 dark:text-slate-400">{{ student.case }}</td>
                            <td class="px-6 py-4">
                                <Badge :type="student.badge">{{ student.status }}</Badge>
                            </td>
                            <td class="px-6 py-4 flex gap-2">
                                <SecondaryButton class="!py-1 !px-2.5 text-xs">Ubah</SecondaryButton>
                                <PrimaryButton class="!py-1 !px-2.5 text-xs">Lihat Detail</PrimaryButton>
                            </td>
                        </tr>
                    </Table>
                </div>
            </section>
        </main>
    </div>
</template>
