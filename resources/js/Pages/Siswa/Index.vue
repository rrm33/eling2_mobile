<script setup>
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout.vue';
import { Head, useForm, router } from '@inertiajs/vue3';
import Card from '@/Components/Card.vue';
import Table from '@/Components/Table.vue';
import Badge from '@/Components/Badge.vue';
import PrimaryButton from '@/Components/PrimaryButton.vue';
import SecondaryButton from '@/Components/SecondaryButton.vue';
import { ref, watch, computed } from 'vue';

const props = defineProps({
    students: Object,
    filters: Object,
    classrooms: Array,
    flash: Object,
});

// Search & Filter State
const search = ref(props.filters.search || '');
const filterClassroomId = ref(props.filters.classroom_id || '');
const filterGender = ref(props.filters.jenis_kelamin || '');

// Modals State
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const showDetailModal = ref(false);
const selectedStudent = ref(null);

// Import Modal State & Form
const showImportModal = ref(false);
const importForm = useForm({
    file: null,
});

const openImportModal = () => {
    importForm.reset();
    importForm.clearErrors();
    showImportModal.value = true;
};

const closeImportModal = () => {
    showImportModal.value = false;
};

const handleFileChange = (e) => {
    importForm.file = e.target.files[0];
};

const submitImport = () => {
    if (!importForm.file) return;
    importForm.post(route('siswa.import'), {
        onSuccess: () => {
            closeImportModal();
            importForm.reset();
        },
    });
};

// Forms
const addForm = useForm({
    nis: '',
    nisn: '',
    nama: '',
    classroom_id: '',
    jenis_kelamin: 'L',
    alamat: '',
    hp: '',
    hp_ortu: '',
});

const editForm = useForm({
    id: null,
    nis: '',
    nisn: '',
    nama: '',
    classroom_id: '',
    jenis_kelamin: 'L',
    alamat: '',
    hp: '',
    hp_ortu: '',
});

// Toast / Flash handling
const showToast = ref(false);
const toastMessage = ref('');

watch(() => props.flash.success, (msg) => {
    if (msg) {
        toastMessage.value = msg;
        showToast.value = true;
        setTimeout(() => {
            showToast.value = false;
        }, 4000);
    }
}, { immediate: true });

// Watching filters and requesting index with router
watch([search, filterClassroomId, filterGender], () => {
    router.get(
        route('siswa.index'),
        {
            search: search.value,
            classroom_id: filterClassroomId.value,
            jenis_kelamin: filterGender.value,
        },
        {
            preserveState: true,
            replace: true,
        }
    );
});

// Modal Actions
const openAddModal = () => {
    addForm.reset();
    addForm.clearErrors();
    showAddModal.value = true;
};

const closeAddModal = () => {
    showAddModal.value = false;
};

const submitAdd = () => {
    addForm.post(route('siswa.store'), {
        onSuccess: () => {
            closeAddModal();
            addForm.reset();
        },
    });
};

const openEditModal = (student) => {
    editForm.clearErrors();
    editForm.id = student.id;
    editForm.nis = student.nis;
    editForm.nisn = student.nisn || '';
    editForm.nama = student.nama;
    editForm.classroom_id = student.classroom_id || '';
    editForm.jenis_kelamin = student.jenis_kelamin;
    editForm.alamat = student.alamat;
    editForm.hp = student.hp;
    editForm.hp_ortu = student.hp_ortu || '';
    showEditModal.value = true;
};

const closeEditModal = () => {
    showEditModal.value = false;
};

const submitEdit = () => {
    editForm.put(route('siswa.update', editForm.id), {
        onSuccess: () => {
            closeEditModal();
        },
    });
};

const openDeleteModal = (student) => {
    selectedStudent.value = student;
    showDeleteModal.value = true;
};

const closeDeleteModal = () => {
    showDeleteModal.value = false;
};

const confirmDelete = () => {
    router.delete(route('siswa.destroy', selectedStudent.value.id), {
        onSuccess: () => {
            closeDeleteModal();
        },
    });
};

const openDetailModal = (student) => {
    selectedStudent.value = student;
    showDetailModal.value = true;
};

const closeDetailModal = () => {
    showDetailModal.value = false;
};

const clearFilters = () => {
    search.value = '';
    filterClassroomId.value = '';
    filterGender.value = '';
};

// Summary metrics (calculated client side for current pagination)
const stats = computed(() => {
    const list = props.students.data || [];
    return {
        total: props.students.total || 0,
        boys: list.filter(s => s.jenis_kelamin === 'L').length,
        girls: list.filter(s => s.jenis_kelamin === 'P').length,
        classes: props.classrooms ? props.classrooms.length : 0,
    };
});
</script>

<template>
    <Head title="Data Siswa Binaan BK" />

    <AuthenticatedLayout>
        <template #header>
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h2 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-700 via-blue-600 to-blue-500 bg-clip-text text-transparent dark:from-blue-400 dark:via-blue-400 dark:to-sky-400 leading-tight">
                        Data Siswa Binaan
                    </h2>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Kelola data siswa secara terpusat untuk kemudahan bimbingan dan konseling.</p>
                </div>
                <div class="flex flex-wrap items-center gap-3">
                    <!-- Download Template Excel -->
                    <a 
                        :href="route('siswa.download-template')"
                        class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 text-xs font-bold shadow-2xs hover:bg-gray-50 dark:hover:bg-slate-800 transition active:scale-95 cursor-pointer"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-emerald-600 dark:text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        <span>Template Excel</span>
                    </a>

                    <!-- Import Excel -->
                    <button 
                        @click="openImportModal"
                        class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 text-xs font-bold shadow-2xs hover:bg-gray-50 dark:hover:bg-slate-800 transition active:scale-95 cursor-pointer"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-blue-600 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                        </svg>
                        <span>Unggah Excel</span>
                    </button>

                    <PrimaryButton 
                        @click="openAddModal"
                        class="bg-gradient-to-r from-blue-600 to-blue-600 border-none hover:from-blue-700 hover:to-blue-700 shadow-md shadow-blue-500/20 px-5 py-2.5 font-bold transition-all transform active:scale-95 flex items-center gap-2"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
                        </svg>
                        Tambah Siswa Baru
                    </PrimaryButton>
                </div>
            </div>
        </template>

        <div class="py-8 relative overflow-hidden min-h-screen">
            <!-- Decorative Blue & Purple Orbs -->
            <div class="absolute top-10 left-1/3 w-80 h-80 bg-blue-500/5 dark:bg-blue-600/5 rounded-full filter blur-3xl pointer-events-none"></div>
            <div class="absolute bottom-20 right-1/4 w-96 h-96 bg-sky-500/5 dark:bg-sky-600/5 rounded-full filter blur-3xl pointer-events-none"></div>

            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 space-y-6 relative z-10">

                <!-- Summary Bar (Dashboard Card Style - 4 Columns for Exact Match Sizing) -->
                <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                    <!-- Total Siswa Binaan -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Total Siswa Binaan</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.total }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>👥 Terdaftar Aktif</span>
                        </div>
                    </Card>

                    <!-- Siswa Laki-laki -->
                    <Card variant="blue" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Siswa Laki-Laki</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.boys }}</h3>
                            </div>
                            <div class="h-12 w-12 bg-white/15 rounded-xl text-white flex items-center justify-center font-black select-none text-lg transition-all duration-300 group-hover:scale-110">
                                L
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>👦 Profil Pria</span>
                        </div>
                    </Card>

                    <!-- Siswa Perempuan -->
                    <Card variant="purple" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-sky-100/80 uppercase tracking-wider">Siswa Perempuan</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.girls }}</h3>
                            </div>
                            <div class="h-12 w-12 bg-white/15 rounded-xl text-white flex items-center justify-center font-black select-none text-lg transition-all duration-300 group-hover:scale-110">
                                P
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-sky-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>👧 Profil Wanita</span>
                        </div>
                    </Card>

                    <!-- Total Kelas Binaan -->
                    <Card variant="sky" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-sky-100/80 uppercase tracking-wider">Kelas Binaan</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.classes }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-sky-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>🏫 Distribusi Kelas</span>
                        </div>
                    </Card>
                </div>

                <!-- Interactive Filters Panel -->
                <Card variant="glass" class="relative overflow-visible">
                    <div class="flex flex-col md:flex-row gap-4 items-center justify-between">
                        <!-- Search input -->
                        <div class="relative w-full md:w-80">
                            <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                                </svg>
                            </div>
                            <input 
                                v-model="search" 
                                type="text"
                                placeholder="Cari berdasarkan Nama, NIS..."
                                class="w-full pl-10 pr-4 py-2 text-sm bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400 shadow-2xs transition-colors duration-200"
                            />
                        </div>

                        <!-- Secondary Filters -->
                        <div class="flex flex-wrap items-center gap-3 w-full md:w-auto">
                            <!-- Filter Kelas -->
                            <select 
                                v-model="filterClassroomId"
                                class="pl-3 pr-8 py-2 text-sm bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs"
                            >
                                <option value="">Semua Kelas</option>
                                <option v-for="c in classrooms" :key="c.id" :value="c.id">{{ c.nama }} ({{ c.major?.kode }})</option>
                            </select>

                            <!-- Filter Gender -->
                            <select 
                                v-model="filterGender"
                                class="pl-3 pr-8 py-2 text-sm bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs"
                            >
                                <option value="">Semua Gender</option>
                                <option value="L">Laki-laki (L)</option>
                                <option value="P">Perempuan (P)</option>
                            </select>

                            <!-- Clear button -->
                            <button 
                                v-if="search || filterClassroomId || filterGender"
                                @click="clearFilters"
                                class="text-xs font-bold text-blue-600 dark:text-blue-400 hover:text-sky-600 dark:hover:text-sky-400 transition py-2 px-3 rounded-lg hover:bg-blue-50 dark:hover:bg-blue-950/40"
                            >
                                Atur Ulang Filter
                            </button>
                        </div>
                    </div>
                </Card>

                <!-- Students Table Core Card -->
                <Card variant="glass">
                    <Table :headers="['NIS / NISN', 'Nama Siswa', 'Kelas', 'Gender', 'Kontak Hubung', 'Aksi']">
                        <tr 
                            v-for="s in students.data" 
                            :key="s.id"
                            class="hover:bg-blue-50/20 dark:hover:bg-blue-950/10 transition duration-150"
                        >
                            <!-- NIS / NISN -->
                            <td class="px-6 py-4 font-mono text-xs text-slate-500 dark:text-slate-400">
                                <div class="font-bold text-slate-700 dark:text-slate-350">{{ s.nis }}</div>
                                <div class="text-[10px] mt-0.5" v-if="s.nisn">NISN: {{ s.nisn }}</div>
                                <div class="text-[10px] text-slate-400 italic" v-else>NISN tidak ada</div>
                            </td>

                            <!-- Nama & Avatar -->
                            <td class="px-6 py-4">
                                <div class="flex items-center gap-3">
                                    <!-- Avatar -->
                                    <div class="h-9 w-9 rounded-xl flex items-center justify-center text-sm font-black text-white shadow-xs select-none bg-gradient-to-br"
                                        :class="s.jenis_kelamin === 'L' ? 'from-blue-400 to-blue-600' : 'from-sky-400 to-sky-600'"
                                    >
                                        {{ s.nama.charAt(0).toUpperCase() }}
                                    </div>
                                    <div>
                                        <span class="font-bold text-slate-900 dark:text-white text-sm block">{{ s.nama }}</span>
                                        <span class="text-[10px] text-slate-400 truncate block max-w-[180px]" :title="s.alamat">{{ s.alamat }}</span>
                                    </div>
                                </div>
                            </td>

                            <!-- Kelas -->
                            <td class="px-6 py-4 text-xs font-semibold text-slate-700 dark:text-slate-300">
                                {{ s.classroom ? `${s.classroom.nama} (${s.classroom.major?.kode})` : s.kelas }}
                            </td>

                            <!-- Gender -->
                            <td class="px-6 py-4">
                                <span class="capitalize text-[10px] font-bold px-2.5 py-1 rounded-full shadow-xs border"
                                    :class="s.jenis_kelamin === 'L' 
                                        ? 'bg-blue-100/80 text-blue-800 border-blue-200/50 dark:bg-blue-950/40 dark:text-blue-350 dark:border-blue-900/50' 
                                        : 'bg-sky-100/80 text-sky-800 border-sky-200/50 dark:bg-sky-950/40 dark:text-sky-350 dark:border-sky-900/50'"
                                >
                                    {{ s.jenis_kelamin === 'L' ? 'Laki-laki' : 'Perempuan' }}
                                </span>
                            </td>

                            <!-- Kontak -->
                            <td class="px-6 py-4 text-xs text-slate-600 dark:text-slate-400 font-medium">
                                <div class="flex items-center gap-1.5">
                                    <span class="text-[10px] bg-blue-50 dark:bg-blue-950/40 border border-blue-100/50 dark:border-blue-900/50 text-blue-600 dark:text-blue-400 px-1 py-0.5 rounded-sm">HP</span>
                                    <span>{{ s.hp }}</span>
                                </div>
                                <div class="flex items-center gap-1.5 mt-1" v-if="s.hp_ortu">
                                    <span class="text-[10px] bg-sky-50 dark:bg-sky-950/40 border border-sky-100/50 dark:border-sky-900/50 text-sky-600 dark:text-sky-400 px-1 py-0.5 rounded-sm">Ortu</span>
                                    <span>{{ s.hp_ortu }}</span>
                                </div>
                            </td>

                            <!-- Aksi -->
                            <td class="px-6 py-4">
                                <div class="flex items-center gap-2">
                                    <!-- Detail -->
                                    <button 
                                        @click="openDetailModal(s)"
                                        class="p-1.5 rounded-lg border border-gray-150 dark:border-gray-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 hover:text-slate-900 dark:hover:text-white transition"
                                        title="Detail Siswa"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                        </svg>
                                    </button>

                                    <!-- Edit -->
                                    <button 
                                        @click="openEditModal(s)"
                                        class="p-1.5 rounded-lg border border-blue-100 dark:border-blue-900/40 hover:bg-blue-50 dark:hover:bg-blue-950/50 text-blue-600 dark:text-blue-400 hover:text-blue-800 transition"
                                        title="Ubah Siswa"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                        </svg>
                                    </button>

                                    <!-- Delete -->
                                    <button 
                                        @click="openDeleteModal(s)"
                                        class="p-1.5 rounded-lg border border-red-100 dark:border-red-900/40 hover:bg-red-50 dark:hover:bg-red-950/50 text-red-600 dark:text-red-400 hover:text-red-800 transition"
                                        title="Hapus Siswa"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-4v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                        </svg>
                                    </button>
                                </div>
                            </td>
                        </tr>

                        <!-- Empty State Inside Table -->
                        <tr v-if="!students.data || students.data.length === 0">
                            <td colspan="6" class="px-6 py-12 text-center">
                                <div class="flex flex-col items-center justify-center gap-3">
                                    <div class="h-12 w-12 rounded-2xl bg-blue-50 dark:bg-blue-950/40 flex items-center justify-center text-blue-500">
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                    </div>
                                    <h4 class="font-bold text-slate-800 dark:text-slate-200">Siswa tidak ditemukan</h4>
                                    <p class="text-xs text-slate-400 max-w-[280px]">Cobalah mengubah filter pencarian atau kelas Anda untuk menemukan siswa yang tepat.</p>
                                </div>
                            </td>
                        </tr>
                    </Table>

                    <!-- Simple Dynamic Pagination -->
                    <div class="mt-6 flex items-center justify-between" v-if="students.links && students.links.length > 3">
                        <span class="text-xs text-slate-400 font-semibold">
                            Menampilkan {{ students.from || 0 }} - {{ students.to || 0 }} dari {{ students.total }} siswa
                        </span>
                        <div class="flex items-center gap-1.5">
                            <button 
                                v-for="link in students.links" 
                                :key="link.label"
                                @click="link.url ? router.get(link.url) : null"
                                class="px-3 py-1.5 rounded-lg border text-xs font-semibold transition"
                                :class="[
                                    link.active 
                                        ? 'bg-blue-600 text-white border-blue-600 shadow-sm' 
                                        : link.url 
                                            ? 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 border-gray-200 dark:border-gray-800 hover:bg-slate-50 dark:hover:bg-slate-850'
                                            : 'text-slate-350 dark:text-slate-600 border-gray-100 dark:border-slate-900 cursor-not-allowed'
                                ]"
                                v-html="link.label"
                            >
                            </button>
                        </div>
                    </div>
                </Card>

            </div>
        </div>

        <!-- ================= ADD SISWA MODAL ================= -->
        <div v-if="showAddModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-xl w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <!-- Modal Header -->
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-blue-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Tambah Data Siswa</h3>
                    <button @click="closeAddModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <!-- Modal Form -->
                <form @submit.prevent="submitAdd" class="p-6 space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                        <!-- NIS -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NIS <span class="text-red-500">*</span></label>
                            <input v-model="addForm.nis" type="text" placeholder="Masukkan NIS..." required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="addForm.errors.nis ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.nis">{{ addForm.errors.nis }}</p>
                        </div>
                        
                        <!-- NISN -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NISN</label>
                            <input v-model="addForm.nisn" type="text" placeholder="Masukkan NISN (Opsional)..."
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="addForm.errors.nisn ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.nisn">{{ addForm.errors.nisn }}</p>
                        </div>
                    </div>

                    <!-- Nama -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nama Lengkap <span class="text-red-500">*</span></label>
                        <input v-model="addForm.nama" type="text" placeholder="Masukkan Nama Lengkap..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.nama ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.nama">{{ addForm.errors.nama }}</p>
                    </div>

                    <div class="grid grid-cols-2 gap-4">
                        <!-- Kelas -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Kelas <span class="text-red-500">*</span></label>
                            <select v-model="addForm.classroom_id" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-white dark:bg-slate-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="addForm.errors.classroom_id ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="" disabled>Pilih Kelas...</option>
                                <option v-for="c in classrooms" :key="c.id" :value="c.id">{{ c.nama }} ({{ c.major?.kode }})</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.classroom_id">{{ addForm.errors.classroom_id }}</p>
                        </div>

                        <!-- Jenis Kelamin -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Jenis Kelamin <span class="text-red-500">*</span></label>
                            <select v-model="addForm.jenis_kelamin" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-white dark:bg-slate-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="addForm.errors.jenis_kelamin ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="L">Laki-laki (L)</option>
                                <option value="P">Perempuan (P)</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.jenis_kelamin">{{ addForm.errors.jenis_kelamin }}</p>
                        </div>
                    </div>

                    <div class="grid grid-cols-2 gap-4">
                        <!-- No. HP -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">No. HP Siswa <span class="text-red-500">*</span></label>
                            <input v-model="addForm.hp" type="text" placeholder="Contoh: 08123456789..." required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="addForm.errors.hp ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.hp">{{ addForm.errors.hp }}</p>
                        </div>

                        <!-- No. HP Ortu -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">No. HP Orang Tua / Wali</label>
                            <input v-model="addForm.hp_ortu" type="text" placeholder="Masukkan No. HP Ortu..."
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="addForm.errors.hp_ortu ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.hp_ortu">{{ addForm.errors.hp_ortu }}</p>
                        </div>
                    </div>

                    <!-- Alamat -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Alamat Rumah <span class="text-red-500">*</span></label>
                        <textarea v-model="addForm.alamat" rows="2" placeholder="Masukkan alamat lengkap rumah..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.alamat ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.alamat">{{ addForm.errors.alamat }}</p>
                    </div>

                    <!-- Modal Actions -->
                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex justify-end gap-3">
                        <SecondaryButton type="button" @click="closeAddModal">
                            Batalkan
                        </SecondaryButton>
                        <PrimaryButton 
                            type="submit" 
                            :disabled="addForm.processing"
                            class="bg-gradient-to-r from-blue-600 to-blue-600 border-none hover:from-blue-700 hover:to-blue-700"
                        >
                            {{ addForm.processing ? 'Menyimpan...' : 'Simpan Siswa' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= EDIT SISWA MODAL ================= -->
        <div v-if="showEditModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-xl w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <!-- Modal Header -->
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-sky-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Ubah Data Siswa</h3>
                    <button @click="closeEditModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <!-- Modal Form -->
                <form @submit.prevent="submitEdit" class="p-6 space-y-4">
                    <div class="grid grid-cols-2 gap-4">
                        <!-- NIS -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NIS <span class="text-red-500">*</span></label>
                            <input v-model="editForm.nis" type="text" placeholder="Masukkan NIS..." required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="editForm.errors.nis ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.nis">{{ editForm.errors.nis }}</p>
                        </div>
                        
                        <!-- NISN -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NISN</label>
                            <input v-model="editForm.nisn" type="text" placeholder="Masukkan NISN (Opsional)..."
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="editForm.errors.nisn ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.nisn">{{ editForm.errors.nisn }}</p>
                        </div>
                    </div>

                    <!-- Nama -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nama Lengkap <span class="text-red-500">*</span></label>
                        <input v-model="editForm.nama" type="text" placeholder="Masukkan Nama Lengkap..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.nama ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.nama">{{ editForm.errors.nama }}</p>
                    </div>

                    <div class="grid grid-cols-2 gap-4">
                        <!-- Kelas -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Kelas <span class="text-red-500">*</span></label>
                            <select v-model="editForm.classroom_id" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-white dark:bg-slate-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="editForm.errors.classroom_id ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="" disabled>Pilih Kelas...</option>
                                <option v-for="c in classrooms" :key="c.id" :value="c.id">{{ c.nama }} ({{ c.major?.kode }})</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.classroom_id">{{ editForm.errors.classroom_id }}</p>
                        </div>

                        <!-- Jenis Kelamin -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Jenis Kelamin <span class="text-red-500">*</span></label>
                            <select v-model="editForm.jenis_kelamin" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-white dark:bg-slate-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="editForm.errors.jenis_kelamin ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="L">Laki-laki (L)</option>
                                <option value="P">Perempuan (P)</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.jenis_kelamin">{{ editForm.errors.jenis_kelamin }}</p>
                        </div>
                    </div>

                    <div class="grid grid-cols-2 gap-4">
                        <!-- No. HP -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">No. HP Siswa <span class="text-red-500">*</span></label>
                            <input v-model="editForm.hp" type="text" placeholder="Contoh: 08123456789..." required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="editForm.errors.hp ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.hp">{{ editForm.errors.hp }}</p>
                        </div>

                        <!-- No. HP Ortu -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">No. HP Orang Tua / Wali</label>
                            <input v-model="editForm.hp_ortu" type="text" placeholder="Masukkan No. HP Ortu..."
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="editForm.errors.hp_ortu ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.hp_ortu">{{ editForm.errors.hp_ortu }}</p>
                        </div>
                    </div>

                    <!-- Alamat -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Alamat Rumah <span class="text-red-500">*</span></label>
                        <textarea v-model="editForm.alamat" rows="2" placeholder="Masukkan alamat lengkap rumah..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.alamat ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.alamat">{{ editForm.errors.alamat }}</p>
                    </div>

                    <!-- Modal Actions -->
                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex justify-end gap-3">
                        <SecondaryButton type="button" @click="closeEditModal">
                            Batalkan
                        </SecondaryButton>
                        <PrimaryButton 
                            type="submit" 
                            :disabled="editForm.processing"
                            class="bg-gradient-to-r from-blue-600 to-sky-600 border-none hover:from-blue-700 hover:to-sky-700"
                        >
                            {{ editForm.processing ? 'Menyimpan...' : 'Perbarui Siswa' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= DETAIL SISWA MODAL ================= -->
        <div v-if="showDetailModal && selectedStudent" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-md w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <!-- Header with avatar background banner -->
                <div class="h-32 bg-gradient-to-br from-blue-500 via-blue-600 to-sky-600 relative flex items-end px-6 pb-4">
                    <button @click="closeDetailModal" class="absolute top-4 right-4 p-1.5 rounded-full bg-black/25 text-white hover:bg-black/45 transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                    <!-- Floating Avatar Circle -->
                    <div class="h-16 w-16 rounded-2xl border-4 border-white dark:border-slate-950 flex items-center justify-center text-2xl font-black text-white shadow-md select-none bg-gradient-to-tr translate-y-6"
                        :class="selectedStudent.jenis_kelamin === 'L' ? 'from-blue-400 to-blue-600' : 'from-sky-400 to-sky-600'"
                    >
                        {{ selectedStudent.nama.charAt(0).toUpperCase() }}
                    </div>
                </div>

                <!-- Student Profile Details Body -->
                <div class="pt-8 px-6 pb-6 space-y-5">
                    <div>
                        <h3 class="text-lg font-black text-slate-900 dark:text-white">{{ selectedStudent.nama }}</h3>
                        <p class="text-xs text-slate-400 mt-0.5">Siswa Kelas: <span class="font-bold text-blue-600 dark:text-blue-400">{{ selectedStudent.classroom ? `${selectedStudent.classroom.nama} (${selectedStudent.classroom.major?.kode})` : selectedStudent.kelas }}</span></p>
                    </div>

                    <div class="grid grid-cols-2 gap-4 border-t border-b border-gray-100 dark:border-slate-900 py-3 text-xs">
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">NIS</span>
                            <span class="font-bold text-slate-800 dark:text-slate-200">{{ selectedStudent.nis }}</span>
                        </div>
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">NISN</span>
                            <span class="font-bold text-slate-800 dark:text-slate-200">{{ selectedStudent.nisn || '-' }}</span>
                        </div>
                        <div class="mt-2">
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">Gender</span>
                            <span class="font-bold text-slate-800 dark:text-slate-200">{{ selectedStudent.jenis_kelamin === 'L' ? 'Laki-Laki' : 'Perempuan' }}</span>
                        </div>
                        <div class="mt-2">
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">Kontak Siswa</span>
                            <span class="font-bold text-slate-800 dark:text-slate-200">{{ selectedStudent.hp }}</span>
                        </div>
                    </div>

                    <div class="text-xs space-y-3">
                        <div v-if="selectedStudent.hp_ortu">
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">No. HP Orang Tua / Wali</span>
                            <span class="font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1 mt-0.5">
                                <span class="inline-block h-2 w-2 rounded-full bg-sky-500"></span>
                                {{ selectedStudent.hp_ortu }}
                            </span>
                        </div>
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider">Alamat Rumah Lengkap</span>
                            <p class="text-slate-600 dark:text-slate-400 mt-1 leading-relaxed bg-slate-50 dark:bg-slate-900/30 p-2.5 rounded-xl border border-gray-150 dark:border-slate-850">
                                {{ selectedStudent.alamat }}
                            </p>
                        </div>
                    </div>

                    <!-- Actions -->
                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex flex-col gap-2">
                        <PrimaryButton 
                            @click="closeDetailModal"
                            class="w-full justify-center bg-gradient-to-r from-blue-600 to-blue-600 border-none hover:from-blue-700 hover:to-blue-700 shadow-xs"
                        >
                            Tutup Detail
                        </PrimaryButton>
                    </div>
                </div>
            </div>
        </div>

        <!-- ================= CONFIRM DELETE MODAL ================= -->
        <div v-if="showDeleteModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-sm w-full p-6 text-center shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-2xl bg-red-100 dark:bg-red-950/40 text-red-600 dark:text-red-400 mb-4 border border-red-200/50 dark:border-red-900/50">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                </div>
                
                <h3 class="text-base font-extrabold text-slate-900 dark:text-white mb-2">Hapus Data Siswa Binaan?</h3>
                <p class="text-xs text-slate-400 mb-6 leading-relaxed">
                    Apakah Anda yakin ingin menghapus data <strong>{{ selectedStudent?.nama }}</strong>? Tindakan ini bersifat permanen dan seluruh riwayat konseling terkait (jika ada) akan terhapus.
                </p>

                <div class="flex gap-3 justify-center">
                    <SecondaryButton @click="closeDeleteModal" class="flex-1 justify-center">
                        Batalkan
                    </SecondaryButton>
                    <PrimaryButton 
                        @click="confirmDelete"
                        class="flex-1 justify-center bg-gradient-to-r from-sky-600 to-sky-700 border-none hover:from-sky-700 hover:to-sky-800 text-white shadow-xs"
                    >
                        Ya, Hapus
                    </PrimaryButton>
                </div>
            </div>
        </div>

        <!-- ================= IMPORT EXCEL MODAL ================= -->
        <div v-if="showImportModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-md w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-blue-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-md">Unggah Data Siswa via Excel</h3>
                    <button @click="closeImportModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <form @submit.prevent="submitImport" class="p-6 space-y-4 text-left">
                    <div class="space-y-2">
                        <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wide">Petunjuk Pengisian:</span>
                        <ul class="text-[11px] text-slate-500 space-y-1 list-disc pl-4 leading-normal">
                            <li>Gunakan template excel resmi yang dapat diunduh di sebelah kanan.</li>
                            <li>Pastikan nama kelas diisi dengan nama kelas yang valid (contoh: XII RPL 1).</li>
                            <li>Kolom Jenis Kelamin harus berupa <strong>L</strong> atau <strong>P</strong>.</li>
                            <li>Jika NIS sudah terdaftar di sistem, data siswa yang bersangkutan akan diperbarui otomatis.</li>
                        </ul>
                    </div>

                    <!-- File input -->
                    <div class="border-2 border-dashed border-gray-200 dark:border-slate-800 rounded-xl p-6 text-center hover:border-blue-500 transition duration-200 relative">
                        <input 
                            type="file" 
                            accept=".xlsx, .xls, .csv"
                            @change="handleFileChange"
                            required
                            class="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                        />
                        <div class="space-y-2 pointer-events-none">
                            <div class="mx-auto h-10 w-10 text-slate-400 flex items-center justify-center bg-slate-50 dark:bg-slate-900 rounded-xl">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-emerald-600 dark:text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 13h6m-3-3v6m-9 1V4a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
                                </svg>
                            </div>
                            <span class="block text-xs font-bold text-slate-700 dark:text-slate-300">
                                {{ importForm.file ? importForm.file.name : 'Pilih File Excel (.xlsx, .xls, .csv)' }}
                            </span>
                            <span class="block text-[10px] text-slate-400">Maksimal ukuran file: 5MB</span>
                        </div>
                    </div>
                    <p class="text-[10px] text-red-500 mt-1" v-if="importForm.errors.file">{{ importForm.errors.file }}</p>

                    <!-- Import Errors -->
                    <div 
                        v-if="$page.props.errors.import_errors" 
                        class="p-3 bg-red-50 dark:bg-red-950/20 border border-red-100 dark:border-red-900/40 rounded-xl text-[10px] text-red-600 dark:text-red-400 whitespace-pre-line leading-relaxed overflow-y-auto max-h-36"
                    >
                        {{ $page.props.errors.import_errors }}
                    </div>

                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex justify-end gap-3">
                        <SecondaryButton type="button" @click="closeImportModal">
                            Batalkan
                        </SecondaryButton>
                        <PrimaryButton 
                            type="submit" 
                            :disabled="importForm.processing || !importForm.file"
                            class="bg-gradient-to-r from-blue-600 to-blue-600 border-none hover:from-blue-700 hover:to-blue-700 font-bold"
                        >
                            {{ importForm.processing ? 'Mengunggah...' : 'Unggah & Import' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= DYNAMIC TOAST SLIDE IN ================= -->
        <Transition
            enter-active-class="transform ease-out duration-300 transition"
            enter-from-class="translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-2"
            enter-to-class="translate-y-0 opacity-100 sm:translate-x-0"
            leave-active-class="transition ease-in duration-100"
            leave-from-class="opacity-100"
            leave-to-class="opacity-0"
        >
            <div v-if="showToast" class="fixed top-5 right-5 z-100 max-w-sm w-full bg-white dark:bg-slate-900 border border-slate-200/60 dark:border-slate-800/80 rounded-2xl shadow-2xl p-4 flex items-center gap-3 backdrop-blur-md">
                <div class="p-2 rounded-xl bg-blue-500/10 text-blue-500 dark:text-blue-400">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <div class="flex-1">
                    <p class="text-xs font-bold text-slate-900 dark:text-white">Berhasil!</p>
                    <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">{{ toastMessage }}</p>
                </div>
                <button @click="showToast = false" class="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                    </svg>
                </button>
            </div>
        </Transition>

    </AuthenticatedLayout>
</template>
