<script setup>
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout.vue';
import { Head, useForm, router } from '@inertiajs/vue3';
import Card from '@/Components/Card.vue';
import Table from '@/Components/Table.vue';
import PrimaryButton from '@/Components/PrimaryButton.vue';
import SecondaryButton from '@/Components/SecondaryButton.vue';
import SearchableSelect from '@/Components/SearchableSelect.vue';
import { ref, watch, computed } from 'vue';

const props = defineProps({
    counselings: Object,
    students: Array,
    teachers: Array,
    classrooms: Array,
    filters: Object,
    flash: Object,
});

// Search & Filter State
const search = ref(props.filters.search || '');
const jenisLayanan = ref(props.filters.jenis_layanan || '');
const status = ref(props.filters.status || '');
const tanggal = ref(props.filters.tanggal || '');

// Modals State
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const showDetailModal = ref(false);
const selectedCounseling = ref(null);

// Class ID references for forms
const addClassId = ref(null);
const editClassId = ref(null);

// Get today's date formatted as YYYY-MM-DD
const getTodayDate = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
};

// Forms
const addForm = useForm({
    student_id: '',
    guru_bk_id: '',
    tanggal: getTodayDate(),
    jenis_layanan: 'Pribadi',
    masalah: '',
    solusi: '',
    status: 'Selesai',
});

const editForm = useForm({
    id: null,
    student_id: '',
    guru_bk_id: '',
    tanggal: '',
    jenis_layanan: 'Pribadi',
    masalah: '',
    solusi: '',
    status: 'Selesai',
});

// Options mapping for SearchableSelect
const classroomOptions = computed(() => {
    return (props.classrooms || []).map(c => ({
        value: c.id,
        label: c.nama,
        info: c.major ? c.major.kode : '',
    }));
});

const teacherOptions = computed(() => {
    return (props.teachers || []).map(t => ({
        value: t.id,
        label: t.nama,
        info: t.nip ? `NIP: ${t.nip}` : '',
    }));
});

const addStudentOptions = computed(() => {
    if (!addClassId.value) return [];
    return (props.students || [])
        .filter(s => s.classroom_id === addClassId.value)
        .map(s => ({
            value: s.id,
            label: s.nama,
            info: `NIS: ${s.nis}`,
        }));
});

const editStudentOptions = computed(() => {
    if (!editClassId.value) return [];
    return (props.students || [])
        .filter(s => s.classroom_id === editClassId.value)
        .map(s => ({
            value: s.id,
            label: s.nama,
            info: `NIS: ${s.nis}`,
        }));
});

// Watch class selections to reset selected student if class changes
watch(addClassId, (newClassVal) => {
    const currentStudent = props.students.find(s => s.id === addForm.student_id);
    if (!currentStudent || currentStudent.classroom_id !== newClassVal) {
        addForm.student_id = '';
    }
});

watch(editClassId, (newClassVal) => {
    const currentStudent = props.students.find(s => s.id === editForm.student_id);
    if (!currentStudent || currentStudent.classroom_id !== newClassVal) {
        editForm.student_id = '';
    }
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

// Watching search filter and requesting index with router
const triggerSearch = () => {
    router.get(
        route('konseling.index'),
        { 
            search: search.value,
            jenis_layanan: jenisLayanan.value,
            status: status.value,
            tanggal: tanggal.value,
        },
        { preserveState: true, replace: true }
    );
};

watch(search, () => triggerSearch());
watch(jenisLayanan, () => triggerSearch());
watch(status, () => triggerSearch());
watch(tanggal, () => triggerSearch());

// Modal Actions
const openAddModal = () => {
    addForm.reset();
    addForm.clearErrors();
    addForm.tanggal = getTodayDate();
    addClassId.value = null;
    if (props.teachers && props.teachers.length > 0) {
        addForm.guru_bk_id = props.teachers[0].id;
    }
    showAddModal.value = true;
};

const closeAddModal = () => {
    showAddModal.value = false;
};

const submitAdd = () => {
    addForm.post(route('konseling.store'), {
        onSuccess: () => {
            closeAddModal();
            addForm.reset();
        },
    });
};

const openEditModal = (counseling) => {
    editForm.clearErrors();
    editForm.id = counseling.id;
    editForm.student_id = counseling.student_id;
    editForm.guru_bk_id = counseling.guru_bk_id;
    editForm.tanggal = counseling.tanggal;
    editForm.jenis_layanan = counseling.jenis_layanan;
    editForm.masalah = counseling.masalah;
    editForm.solusi = counseling.solusi || '';
    editForm.status = counseling.status;

    // Find and set editClassId from student's class
    const student = props.students.find(s => s.id === counseling.student_id);
    if (student) {
        editClassId.value = student.classroom_id;
    } else {
        editClassId.value = null;
    }

    showEditModal.value = true;
};

const closeEditModal = () => {
    showEditModal.value = false;
};

const submitEdit = () => {
    editForm.put(route('konseling.update', editForm.id), {
        onSuccess: () => {
            closeEditModal();
        },
    });
};

const openDetailModal = (counseling) => {
    selectedCounseling.value = counseling;
    showDetailModal.value = true;
};

const closeDetailModal = () => {
    showDetailModal.value = false;
};

const openDeleteModal = (counseling) => {
    selectedCounseling.value = counseling;
    showDeleteModal.value = true;
};

const closeDeleteModal = () => {
    showDeleteModal.value = false;
};

const confirmDelete = () => {
    router.delete(route('konseling.destroy', selectedCounseling.value.id), {
        onSuccess: () => {
            closeDeleteModal();
        },
    });
};

const clearFilters = () => {
    search.value = '';
    jenisLayanan.value = '';
    status.value = '';
    tanggal.value = '';
};

// Summary metrics computed client-side
const stats = computed(() => {
    let total = props.counselings.total || 0;
    
    // Check if we can calculate active statuses from current page data (for visual dashboard metrics)
    const list = props.counselings.data || [];
    const selesaiCount = list.filter(c => c.status === 'Selesai').length;
    const prosesCount = list.filter(c => c.status === 'Proses').length;
    const rujukanCount = list.filter(c => c.status === 'Rujukan').length;

    return {
        total,
        selesai: selesaiCount,
        proses: prosesCount,
        rujukan: rujukanCount,
    };
});
</script>

<template>
    <Head title="Layanan Konseling Siswa" />

    <AuthenticatedLayout>
        <template #header>
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h2 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-700 via-blue-600 to-blue-500 bg-clip-text text-transparent dark:from-blue-400 dark:via-blue-400 dark:to-sky-400 leading-tight">
                        Layanan Konseling
                    </h2>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Catat, bimbing, dan pantau penyelesaian kasus serta sesi konseling siswa.</p>
                </div>
                <div>
                    <button 
                        @click="openAddModal"
                        class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-600 hover:from-blue-700 hover:to-blue-700 text-white text-xs font-black shadow-lg shadow-blue-500/20 hover:shadow-blue-500/30 transition-all duration-300 transform hover:-translate-y-0.5 cursor-pointer"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                        </svg>
                        <span>Tambah Catatan Konseling</span>
                    </button>
                </div>
            </div>
        </template>

        <div class="py-8 relative overflow-hidden min-h-screen">
            <!-- Decorative Background Orbs -->
            <div class="absolute top-10 left-1/3 w-80 h-80 bg-blue-500/5 dark:bg-blue-600/5 rounded-full filter blur-3xl pointer-events-none"></div>
            <div class="absolute bottom-20 right-1/4 w-96 h-96 bg-sky-500/5 dark:bg-sky-600/5 rounded-full filter blur-3xl pointer-events-none"></div>

            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 space-y-6 relative z-10">
                
                <!-- Summary Cards -->
                <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
                    <!-- Total -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Total Konseling</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.total }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>📝 Semua Sesi Terdata</span>
                        </div>
                    </Card>

                    <!-- Selesai -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group bg-gradient-to-br from-emerald-600 to-teal-600 border-emerald-500/25">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-emerald-100/80 uppercase tracking-wider">Selesai (Halaman ini)</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.selesai }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-emerald-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>✅ Selesai Ditangani</span>
                        </div>
                    </Card>

                    <!-- Proses -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group bg-gradient-to-br from-amber-500 to-orange-600 border-amber-500/25">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-amber-100/80 uppercase tracking-wider">Proses (Halaman ini)</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.proses }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-amber-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>⏳ Butuh Tindak Lanjut</span>
                        </div>
                    </Card>

                    <!-- Rujukan -->
                    <Card variant="indigo" hoverable class="relative overflow-hidden group bg-gradient-to-br from-red-600 to-rose-600 border-red-500/25">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-red-100/80 uppercase tracking-wider">Rujukan (Halaman ini)</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.rujukan }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-red-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>🚨 Dirujuk ke Pihak Lain</span>
                        </div>
                    </Card>
                </div>

                <!-- Filters Panel -->
                <Card variant="glass" class="relative overflow-visible">
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 items-end">
                        <!-- Search input -->
                        <div>
                            <label class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Kata Kunci</label>
                            <div class="relative">
                                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                                    </svg>
                                </div>
                                <input 
                                    v-model="search" 
                                    type="text"
                                    placeholder="Cari nama, NIS, masalah..."
                                    class="w-full pl-10 pr-4 py-2 text-xs bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400 shadow-2xs transition-colors duration-200"
                                />
                            </div>
                        </div>

                        <!-- Layanan Select -->
                        <div>
                            <label class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Jenis Layanan</label>
                            <select 
                                v-model="jenisLayanan"
                                class="w-full px-3.5 py-2 text-xs bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs transition-colors duration-200 appearance-none cursor-pointer"
                            >
                                <option value="">Semua Layanan</option>
                                <option value="Pribadi">Pribadi</option>
                                <option value="Sosial">Sosial</option>
                                <option value="Belajar">Belajar</option>
                                <option value="Karir">Karir</option>
                            </select>
                        </div>

                        <!-- Status Select -->
                        <div>
                            <label class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Status</label>
                            <select 
                                v-model="status"
                                class="w-full px-3.5 py-2 text-xs bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs transition-colors duration-200 appearance-none cursor-pointer"
                            >
                                <option value="">Semua Status</option>
                                <option value="Proses">Proses</option>
                                <option value="Selesai">Selesai</option>
                                <option value="Rujukan">Rujukan</option>
                            </select>
                        </div>

                        <!-- Date Picker -->
                        <div class="flex gap-2 items-center">
                            <div class="flex-1">
                                <label class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1.5">Tanggal</label>
                                <input 
                                    v-model="tanggal"
                                    type="date"
                                    class="w-full px-3.5 py-2 text-xs bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs appearance-none cursor-pointer"
                                />
                            </div>
                            <button 
                                v-if="search || jenisLayanan || status || tanggal"
                                @click="clearFilters"
                                class="text-xs font-bold text-red-600 dark:text-red-400 hover:text-red-800 transition py-2 px-3 rounded-xl border border-red-100 dark:border-red-950/40 hover:bg-red-50 dark:hover:bg-red-950/20 h-fit"
                            >
                                Reset
                            </button>
                        </div>
                    </div>
                </Card>

                <!-- Counselings Table Card -->
                <Card variant="glass">
                    <Table :headers="['Tanggal', 'Siswa / Kelas', 'Guru Pembimbing BK', 'Layanan', 'Masalah / Kasus', 'Status', 'Aksi']">
                        <tr 
                            v-for="c in counselings.data" 
                            :key="c.id"
                            class="hover:bg-blue-50/20 dark:hover:bg-blue-950/10 transition duration-150"
                        >
                            <!-- Tanggal -->
                            <td class="px-6 py-4 text-xs font-mono font-bold text-slate-800 dark:text-white">
                                {{ c.tanggal }}
                            </td>

                            <!-- Siswa -->
                            <td class="px-6 py-4">
                                <div class="text-sm font-bold text-slate-800 dark:text-white">
                                    {{ c.student.nama }}
                                </div>
                                <div class="text-[10px] text-slate-400 font-semibold mt-0.5" v-if="c.student.classroom">
                                    {{ c.student.classroom.nama }} {{ c.student.classroom.major ? '(' + c.student.classroom.major.kode + ')' : '' }}
                                </div>
                            </td>

                            <!-- Guru BK -->
                            <td class="px-6 py-4 text-xs font-semibold text-slate-700 dark:text-slate-350">
                                {{ c.guru_bk.nama }}
                            </td>

                            <!-- Layanan -->
                            <td class="px-6 py-4">
                                <span 
                                    class="text-[9px] font-black px-2 py-0.5 rounded-md border"
                                    :class="[
                                        c.jenis_layanan === 'Pribadi' ? 'bg-sky-50 text-sky-700 border-sky-200 dark:bg-sky-950/40 dark:text-sky-400 dark:border-sky-900/50' : '',
                                        c.jenis_layanan === 'Sosial' ? 'bg-indigo-50 text-indigo-700 border-indigo-200 dark:bg-indigo-950/40 dark:text-indigo-400 dark:border-indigo-900/50' : '',
                                        c.jenis_layanan === 'Belajar' ? 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-900/50' : '',
                                        c.jenis_layanan === 'Karir' ? 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-900/50' : '',
                                    ]"
                                >
                                    {{ c.jenis_layanan.toUpperCase() }}
                                </span>
                            </td>

                            <!-- Masalah -->
                            <td class="px-6 py-4 text-xs text-slate-600 dark:text-slate-300 max-w-[200px] truncate">
                                {{ c.masalah }}
                            </td>

                            <!-- Status -->
                            <td class="px-6 py-4">
                                <span 
                                    class="text-[10px] font-black px-2.5 py-0.5 rounded-full border"
                                    :class="[
                                        c.status === 'Selesai' ? 'bg-emerald-50 text-emerald-700 border-emerald-250 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-900/50' : '',
                                        c.status === 'Proses' ? 'bg-amber-50 text-amber-700 border-amber-250 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-900/50' : '',
                                        c.status === 'Rujukan' ? 'bg-red-50 text-red-700 border-red-250 dark:bg-red-950/40 dark:text-red-400 dark:border-red-900/50' : '',
                                    ]"
                                >
                                    {{ c.status }}
                                </span>
                            </td>

                            <!-- Aksi -->
                            <td class="px-6 py-4">
                                <div class="flex items-center gap-1.5">
                                    <!-- Detail -->
                                    <button 
                                        @click="openDetailModal(c)"
                                        class="p-1.5 rounded-lg border border-slate-150 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 hover:text-slate-900 dark:hover:text-white transition"
                                        title="Detail Konseling"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                        </svg>
                                    </button>

                                    <!-- Edit -->
                                    <button 
                                        @click="openEditModal(c)"
                                        class="p-1.5 rounded-lg border border-blue-100 dark:border-blue-900/40 hover:bg-blue-50 dark:hover:bg-blue-950/50 text-blue-600 dark:text-blue-400 hover:text-blue-800 transition"
                                        title="Ubah Sesi"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                        </svg>
                                    </button>

                                    <!-- Delete -->
                                    <button 
                                        @click="openDeleteModal(c)"
                                        class="p-1.5 rounded-lg border border-red-100 dark:border-red-900/40 hover:bg-red-50 dark:hover:bg-red-950/50 text-red-600 dark:text-red-400 hover:text-red-800 transition"
                                        title="Hapus Sesi"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-4v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                        </svg>
                                    </button>
                                </div>
                            </td>
                        </tr>

                        <!-- Empty State -->
                        <tr v-if="!counselings.data || counselings.data.length === 0">
                            <td colspan="7" class="px-6 py-12 text-center">
                                <div class="flex flex-col items-center justify-center gap-3">
                                    <div class="h-12 w-12 rounded-2xl bg-blue-50 dark:bg-blue-950/40 flex items-center justify-center text-blue-500">
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                    </div>
                                    <h4 class="font-bold text-slate-800 dark:text-slate-200">Sesi konseling tidak ditemukan</h4>
                                    <p class="text-xs text-slate-400 max-w-[280px]">Belum ada sesi konseling tercatat untuk kriteria pencarian ini.</p>
                                </div>
                            </td>
                        </tr>
                    </Table>

                    <!-- Pagination -->
                    <div class="mt-6 flex items-center justify-between" v-if="counselings.links && counselings.links.length > 3">
                        <span class="text-xs text-slate-400 font-semibold">
                            Menampilkan {{ counselings.from || 0 }} - {{ counselings.to || 0 }} dari {{ counselings.total }} Sesi
                        </span>
                        <div class="flex items-center gap-1.5">
                            <button 
                                v-for="link in counselings.links" 
                                :key="link.label"
                                @click="link.url ? router.get(link.url) : null"
                                class="px-3 py-1.5 rounded-lg border text-xs font-semibold transition"
                                :class="[
                                    link.active 
                                        ? 'bg-blue-600 text-white border-blue-600 shadow-sm' 
                                        : link.url 
                                            ? 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-355 border-gray-200 dark:border-gray-800 hover:bg-slate-50 dark:hover:bg-slate-850'
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

        <!-- ================= ADD CONSELING MODAL ================= -->
        <div v-if="showAddModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-2xl w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-blue-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Tambah Catatan Konseling</h3>
                    <button @click="closeAddModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <form @submit.prevent="submitAdd" class="p-6 space-y-4 max-h-[75vh] overflow-y-auto text-left">
                    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <!-- Kelas -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Pilih Kelas <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="addClassId"
                                :options="classroomOptions"
                                placeholder="-- Pilih Kelas --"
                            />
                        </div>

                        <!-- Siswa -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Pilih Siswa <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="addForm.student_id"
                                :options="addStudentOptions"
                                :disabled="!addClassId"
                                :placeholder="addClassId ? '-- Pilih Siswa --' : 'Pilih Kelas Terlebih Dahulu'"
                                :error="addForm.errors.student_id"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.student_id">{{ addForm.errors.student_id }}</p>
                        </div>

                        <!-- Guru BK -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Guru Pembimbing BK <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="addForm.guru_bk_id"
                                :options="teacherOptions"
                                placeholder="-- Pilih Guru BK --"
                                :error="addForm.errors.guru_bk_id"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.guru_bk_id">{{ addForm.errors.guru_bk_id }}</p>
                        </div>
                    </div>

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <!-- Tanggal -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Tanggal Konseling <span class="text-red-500">*</span></label>
                            <input v-model="addForm.tanggal" type="date" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="addForm.errors.tanggal ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.tanggal">{{ addForm.errors.tanggal }}</p>
                        </div>

                        <!-- Jenis Layanan -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Jenis Konseling / Layanan <span class="text-red-500">*</span></label>
                            <select v-model="addForm.jenis_layanan" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="addForm.errors.jenis_layanan ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="Pribadi">Pribadi</option>
                                <option value="Sosial">Sosial</option>
                                <option value="Belajar">Belajar</option>
                                <option value="Karir">Karir</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.jenis_layanan">{{ addForm.errors.jenis_layanan }}</p>
                        </div>
                    </div>

                    <!-- Masalah -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Keluhan / Masalah Siswa <span class="text-red-500">*</span></label>
                        <textarea v-model="addForm.masalah" rows="4" placeholder="Tuliskan keluhan atau pelanggaran/masalah detail siswa di sini..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.masalah ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.masalah">{{ addForm.errors.masalah }}</p>
                    </div>

                    <!-- Solusi / Rekomendasi -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Solusi / Tindak Lanjut</label>
                        <textarea v-model="addForm.solusi" rows="3" placeholder="Rencana tindak lanjut, solusi, atau kesepakatan konseling..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.solusi ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.solusi">{{ addForm.errors.solusi }}</p>
                    </div>

                    <!-- Status -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-2">Status Penanganan <span class="text-red-500">*</span></label>
                        <div class="flex items-center gap-6">
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="addForm.status" value="Selesai" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Selesai</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="addForm.status" value="Proses" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Proses</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="addForm.status" value="Rujukan" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Rujukan</span>
                            </label>
                        </div>
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.status">{{ addForm.errors.status }}</p>
                    </div>

                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex justify-end gap-3">
                        <SecondaryButton type="button" @click="closeAddModal">
                            Batalkan
                        </SecondaryButton>
                        <PrimaryButton 
                            type="submit" 
                            :disabled="addForm.processing"
                            class="bg-gradient-to-r from-blue-600 to-blue-600 border-none hover:from-blue-700 hover:to-blue-700"
                        >
                            {{ addForm.processing ? 'Menyimpan...' : 'Simpan Catatan' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= EDIT CONSELING MODAL ================= -->
        <div v-if="showEditModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-2xl w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-sky-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Ubah Catatan Konseling</h3>
                    <button @click="closeEditModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <form @submit.prevent="submitEdit" class="p-6 space-y-4 max-h-[75vh] overflow-y-auto text-left">
                    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <!-- Kelas -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Pilih Kelas <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="editClassId"
                                :options="classroomOptions"
                                placeholder="-- Pilih Kelas --"
                            />
                        </div>

                        <!-- Siswa -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Pilih Siswa <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="editForm.student_id"
                                :options="editStudentOptions"
                                :disabled="!editClassId"
                                :placeholder="editClassId ? '-- Pilih Siswa --' : 'Pilih Kelas Terlebih Dahulu'"
                                :error="editForm.errors.student_id"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.student_id">{{ editForm.errors.student_id }}</p>
                        </div>

                        <!-- Guru BK -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1.5">Guru Pembimbing BK <span class="text-red-500">*</span></label>
                            <SearchableSelect 
                                v-model="editForm.guru_bk_id"
                                :options="teacherOptions"
                                placeholder="-- Pilih Guru BK --"
                                :error="editForm.errors.guru_bk_id"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.guru_bk_id">{{ editForm.errors.guru_bk_id }}</p>
                        </div>
                    </div>

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <!-- Tanggal -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Tanggal Konseling <span class="text-red-500">*</span></label>
                            <input v-model="editForm.tanggal" type="date" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="editForm.errors.tanggal ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.tanggal">{{ editForm.errors.tanggal }}</p>
                        </div>

                        <!-- Jenis Layanan -->
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Jenis Konseling / Layanan <span class="text-red-500">*</span></label>
                            <select v-model="editForm.jenis_layanan" required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white"
                                :class="editForm.errors.jenis_layanan ? 'border-red-500' : 'border-gray-200'"
                            >
                                <option value="Pribadi">Pribadi</option>
                                <option value="Sosial">Sosial</option>
                                <option value="Belajar">Belajar</option>
                                <option value="Karir">Karir</option>
                            </select>
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.jenis_layanan">{{ editForm.errors.jenis_layanan }}</p>
                        </div>
                    </div>

                    <!-- Masalah -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Keluhan / Masalah Siswa <span class="text-red-500">*</span></label>
                        <textarea v-model="editForm.masalah" rows="4" placeholder="Tuliskan keluhan atau pelanggaran/masalah detail siswa di sini..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.masalah ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.masalah">{{ editForm.errors.masalah }}</p>
                    </div>

                    <!-- Solusi / Rekomendasi -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Solusi / Tindak Lanjut</label>
                        <textarea v-model="editForm.solusi" rows="3" placeholder="Rencana tindak lanjut, solusi, atau kesepakatan konseling..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.solusi ? 'border-red-500' : 'border-gray-200'"
                        ></textarea>
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.solusi">{{ editForm.errors.solusi }}</p>
                    </div>

                    <!-- Status -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-2">Status Penanganan <span class="text-red-500">*</span></label>
                        <div class="flex items-center gap-6">
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="editForm.status" value="Selesai" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Selesai</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="editForm.status" value="Proses" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Proses</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="editForm.status" value="Rujukan" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Rujukan</span>
                            </label>
                        </div>
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.status">{{ editForm.errors.status }}</p>
                    </div>

                    <div class="pt-4 border-t border-gray-100 dark:border-slate-900 flex justify-end gap-3">
                        <SecondaryButton type="button" @click="closeEditModal">
                            Batalkan
                        </SecondaryButton>
                        <PrimaryButton 
                            type="submit" 
                            :disabled="editForm.processing"
                            class="bg-gradient-to-r from-blue-600 to-sky-600 border-none hover:from-blue-700 hover:to-sky-700"
                        >
                            {{ editForm.processing ? 'Menyimpan...' : 'Perbarui Catatan' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= DETAIL CONSELING MODAL ================= -->
        <div v-if="showDetailModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-2xl w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-blue-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg flex items-center gap-2">
                        <span>Detail Sesi Konseling</span>
                        <span 
                            class="text-[10px] font-black px-2 py-0.5 rounded-full border text-xs"
                            :class="[
                                selectedCounseling?.status === 'Selesai' ? 'bg-emerald-50 text-emerald-700 border-emerald-250 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-900/50' : '',
                                selectedCounseling?.status === 'Proses' ? 'bg-amber-50 text-amber-700 border-amber-250 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-900/50' : '',
                                selectedCounseling?.status === 'Rujukan' ? 'bg-red-50 text-red-700 border-red-250 dark:bg-red-950/40 dark:text-red-400 dark:border-red-900/50' : '',
                            ]"
                        >
                            {{ selectedCounseling?.status }}
                        </span>
                    </h3>
                    <button @click="closeDetailModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <div class="p-6 space-y-6 max-h-[75vh] overflow-y-auto text-left">
                    <!-- Participant Details -->
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 bg-slate-50 dark:bg-slate-900/60 p-4 rounded-xl border border-gray-150/50 dark:border-gray-800/80">
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1">Informasi Siswa</span>
                            <span class="block text-sm font-bold text-slate-800 dark:text-white">{{ selectedCounseling?.student.nama }}</span>
                            <span class="block text-xs text-slate-400 font-semibold mt-0.5">NIS: {{ selectedCounseling?.student.nis }}</span>
                            <span class="block text-xs text-slate-400 mt-0.5" v-if="selectedCounseling?.student.classroom">
                                Kelas: {{ selectedCounseling?.student.classroom.nama }} {{ selectedCounseling?.student.classroom.major ? '(' + selectedCounseling?.student.classroom.major.kode + ')' : '' }}
                            </span>
                        </div>
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1">Guru Pendimbing BK</span>
                            <span class="block text-sm font-bold text-slate-800 dark:text-white">{{ selectedCounseling?.guru_bk.nama }}</span>
                            <span class="block text-xs text-slate-400 font-semibold mt-0.5" v-if="selectedCounseling?.guru_bk.nip">NIP: {{ selectedCounseling?.guru_bk.nip }}</span>
                        </div>
                    </div>

                    <!-- Date & Type -->
                    <div class="grid grid-cols-2 gap-4">
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1">Tanggal Konseling</span>
                            <span class="text-xs font-mono font-bold text-slate-800 dark:text-white">{{ selectedCounseling?.tanggal }}</span>
                        </div>
                        <div>
                            <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-1">Jenis Layanan / Konseling</span>
                            <span 
                                class="inline-block text-[9px] font-black px-2 py-0.5 rounded-md border mt-1"
                                :class="[
                                    selectedCounseling?.jenis_layanan === 'Pribadi' ? 'bg-sky-50 text-sky-700 border-sky-200 dark:bg-sky-950/40 dark:text-sky-400 dark:border-sky-900/50' : '',
                                    selectedCounseling?.jenis_layanan === 'Sosial' ? 'bg-indigo-50 text-indigo-700 border-indigo-200 dark:bg-indigo-950/40 dark:text-indigo-400 dark:border-indigo-900/50' : '',
                                    selectedCounseling?.jenis_layanan === 'Belajar' ? 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-900/50' : '',
                                    selectedCounseling?.jenis_layanan === 'Karir' ? 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-900/50' : '',
                                ]"
                            >
                                {{ selectedCounseling?.jenis_layanan.toUpperCase() }}
                            </span>
                        </div>
                    </div>

                    <!-- Masalah -->
                    <div>
                        <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-2">Kasus / Masalah Detail</span>
                        <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-900/60 border border-gray-150/50 dark:border-gray-800/80 text-xs text-slate-700 dark:text-slate-350 whitespace-pre-line leading-relaxed">
                            {{ selectedCounseling?.masalah }}
                        </div>
                    </div>

                    <!-- Solusi -->
                    <div>
                        <span class="block text-[10px] font-black text-slate-400 uppercase tracking-wider mb-2">Solusi / Rekomendasi Penanganan</span>
                        <div 
                            v-if="selectedCounseling?.solusi" 
                            class="p-4 rounded-xl bg-emerald-50/50 dark:bg-emerald-950/20 border border-emerald-150/40 dark:border-emerald-900/30 text-xs text-slate-700 dark:text-slate-350 whitespace-pre-line leading-relaxed"
                        >
                            {{ selectedCounseling?.solusi }}
                        </div>
                        <div v-else class="text-xs text-slate-400 italic">
                            Belum ada catatan solusi atau tindak lanjut yang ditulis.
                        </div>
                    </div>
                </div>

                <div class="px-6 py-4 bg-slate-50 dark:bg-slate-900/50 border-t border-gray-100 dark:border-slate-900 flex justify-end">
                    <SecondaryButton @click="closeDetailModal">
                        Tutup Detail
                    </SecondaryButton>
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
                
                <h3 class="text-base font-extrabold text-slate-900 dark:text-white mb-2">Hapus Catatan Konseling?</h3>
                <p class="text-xs text-slate-400 mb-6 leading-relaxed">
                    Apakah Anda yakin ingin menghapus catatan sesi konseling milik siswa <strong>{{ selectedCounseling?.student.nama }}</strong>? Tindakan ini bersifat permanen dan tidak bisa dibatalkan.
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

        <!-- ================= DYNAMIC TOAST ================= -->
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
