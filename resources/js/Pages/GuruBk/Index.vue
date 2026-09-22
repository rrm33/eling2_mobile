<script setup>
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout.vue';
import { Head, useForm, router } from '@inertiajs/vue3';
import Card from '@/Components/Card.vue';
import Table from '@/Components/Table.vue';
import PrimaryButton from '@/Components/PrimaryButton.vue';
import SecondaryButton from '@/Components/SecondaryButton.vue';
import { ref, watch, computed } from 'vue';

const props = defineProps({
    guruBks: Object,
    filters: Object,
    flash: Object,
});

// Search & Filter State
const search = ref(props.filters.search || '');
const jenisKelamin = ref(props.filters.jenis_kelamin || '');

// Modals State
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const selectedGuruBk = ref(null);

// Forms
const addForm = useForm({
    nama: '',
    nip: '',
    jenis_kelamin: 'L',
    no_hp: '',
    email: '',
    create_account: false,
    password: '',
});

const editForm = useForm({
    id: null,
    nama: '',
    nip: '',
    jenis_kelamin: 'L',
    no_hp: '',
    email: '',
    create_account: false,
    password: '',
    has_account: false,
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
        route('guru-bk.index'),
        { 
            search: search.value,
            jenis_kelamin: jenisKelamin.value,
        },
        { preserveState: true, replace: true }
    );
};

watch(search, () => {
    triggerSearch();
});

watch(jenisKelamin, () => {
    triggerSearch();
});

// Modal Actions
const openAddModal = () => {
    addForm.reset();
    addForm.clearErrors();
    addForm.create_account = false;
    showAddModal.value = true;
};

const closeAddModal = () => {
    showAddModal.value = false;
};

const submitAdd = () => {
    addForm.post(route('guru-bk.store'), {
        onSuccess: () => {
            closeAddModal();
            addForm.reset();
        },
    });
};

const openEditModal = (guruBk) => {
    editForm.clearErrors();
    editForm.id = guruBk.id;
    editForm.nama = guruBk.nama;
    editForm.nip = guruBk.nip || '';
    editForm.jenis_kelamin = guruBk.jenis_kelamin;
    editForm.no_hp = guruBk.no_hp || '';
    editForm.email = guruBk.email || '';
    editForm.create_account = false;
    editForm.password = '';
    editForm.has_account = !!guruBk.user_id;
    showEditModal.value = true;
};

const closeEditModal = () => {
    showEditModal.value = false;
};

const submitEdit = () => {
    editForm.put(route('guru-bk.update', editForm.id), {
        onSuccess: () => {
            closeEditModal();
        },
    });
};

const openDeleteModal = (guruBk) => {
    selectedGuruBk.value = guruBk;
    showDeleteModal.value = true;
};

const closeDeleteModal = () => {
    showDeleteModal.value = false;
};

const confirmDelete = () => {
    router.delete(route('guru-bk.destroy', selectedGuruBk.value.id), {
        onSuccess: () => {
            closeDeleteModal();
        },
    });
};

const clearFilters = () => {
    search.value = '';
    jenisKelamin.value = '';
};

// Summary metrics computed client-side
const stats = computed(() => {
    return {
        total: props.guruBks.total || 0,
    };
});
</script>

<template>
    <Head title="Data Guru BK" />

    <AuthenticatedLayout>
        <template #header>
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h2 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-blue-700 via-blue-600 to-blue-500 bg-clip-text text-transparent dark:from-blue-400 dark:via-blue-400 dark:to-sky-400 leading-tight">
                        Data Guru BK
                    </h2>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Kelola data guru bimbingan konseling dan akun login mereka.</p>
                </div>
                <div>
                    <button 
                        @click="openAddModal"
                        class="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-blue-600 hover:from-blue-700 hover:to-blue-700 text-white text-xs font-black shadow-lg shadow-blue-500/20 hover:shadow-blue-500/30 transition-all duration-300 transform hover:-translate-y-0.5 cursor-pointer"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                        </svg>
                        <span>Tambah Guru BK</span>
                    </button>
                </div>
            </div>
        </template>

        <div class="py-8 relative overflow-hidden min-h-screen">
            <!-- Decorative Background Orbs -->
            <div class="absolute top-10 left-1/3 w-80 h-80 bg-blue-500/5 dark:bg-blue-600/5 rounded-full filter blur-3xl pointer-events-none"></div>
            <div class="absolute bottom-20 right-1/4 w-96 h-96 bg-sky-500/5 dark:bg-sky-600/5 rounded-full filter blur-3xl pointer-events-none"></div>

            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 space-y-6 relative z-10">
                
                <!-- Summary Card -->
                <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                    <Card variant="indigo" hoverable class="relative overflow-hidden group">
                        <div class="flex justify-between items-start">
                            <div>
                                <p class="text-xs font-bold text-blue-100/80 uppercase tracking-wider">Total Guru BK</p>
                                <h3 class="text-3xl font-black text-white mt-2">{{ stats.total }}</h3>
                            </div>
                            <div class="p-3 bg-white/15 rounded-xl text-white transition-all duration-300 group-hover:scale-110">
                                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                    <path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                                </svg>
                            </div>
                        </div>
                        <div class="mt-4 flex items-center text-xs text-blue-100 font-semibold gap-1.5 bg-white/10 px-2.5 py-1 rounded-md w-fit select-none">
                            <span>💼 Pembimbing BK Sekolah</span>
                        </div>
                    </Card>
                </div>

                <!-- Filters Panel -->
                <Card variant="glass" class="relative overflow-visible">
                    <div class="flex flex-col md:flex-row gap-4 items-center justify-between">
                        <div class="flex flex-col sm:flex-row gap-4 w-full md:w-auto items-stretch sm:items-center">
                            <!-- Search input -->
                            <div class="relative w-full sm:w-80">
                                <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                                    </svg>
                                </div>
                                <input 
                                    v-model="search" 
                                    type="text"
                                    placeholder="Cari Nama, NIP, atau Email..."
                                    class="w-full pl-10 pr-4 py-2 text-sm bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400 shadow-2xs transition-colors duration-200"
                                />
                            </div>

                            <!-- Gender Select -->
                            <div class="relative w-full sm:w-48">
                                <select 
                                    v-model="jenisKelamin"
                                    class="w-full px-3.5 py-2 text-sm bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-xl focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white shadow-2xs transition-colors duration-200 appearance-none cursor-pointer"
                                >
                                    <option value="">Semua Gender</option>
                                    <option value="L">Laki-laki</option>
                                    <option value="P">Perempuan</option>
                                </select>
                            </div>
                        </div>

                        <!-- Clear Filters -->
                        <button 
                            v-if="search || jenisKelamin"
                            @click="clearFilters"
                            class="text-xs font-bold text-blue-600 dark:text-blue-400 hover:text-sky-600 dark:hover:text-sky-400 transition py-2 px-3 rounded-lg hover:bg-blue-50 dark:hover:bg-blue-950/40"
                        >
                            Atur Ulang
                        </button>
                    </div>
                </Card>

                <!-- Guru BK Table Card -->
                <Card variant="glass">
                    <Table :headers="['NIP', 'Nama Lengkap', 'Gender', 'No. HP / Kontak', 'Status Akun', 'Aksi']">
                        <tr 
                            v-for="g in guruBks.data" 
                            :key="g.id"
                            class="hover:bg-blue-50/20 dark:hover:bg-blue-950/10 transition duration-150"
                        >
                            <!-- NIP -->
                            <td class="px-6 py-4">
                                <span class="text-xs font-mono font-bold text-slate-800 dark:text-white" v-if="g.nip">
                                    {{ g.nip }}
                                </span>
                                <span class="text-xs text-slate-400 italic" v-else>
                                    Belum diatur
                                </span>
                            </td>

                            <!-- Nama -->
                            <td class="px-6 py-4 text-sm font-bold text-slate-800 dark:text-white">
                                {{ g.nama }}
                            </td>

                            <!-- Gender -->
                            <td class="px-6 py-4">
                                <span 
                                    class="text-[10px] font-black px-2 py-0.5 rounded-md border"
                                    :class="[
                                        g.jenis_kelamin === 'L' 
                                            ? 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/40 dark:text-blue-400 dark:border-blue-900/50' 
                                            : 'bg-rose-50 text-rose-700 border-rose-200 dark:bg-rose-950/40 dark:text-rose-400 dark:border-rose-900/50'
                                    ]"
                                >
                                    {{ g.jenis_kelamin === 'L' ? 'LAKI-LAKI' : 'PEREMPUAN' }}
                                </span>
                            </td>

                            <!-- Kontak -->
                            <td class="px-6 py-4">
                                <div class="text-xs space-y-1">
                                    <div class="flex items-center gap-1.5" v-if="g.no_hp">
                                        <span class="text-[10px] font-bold bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400 px-1 py-0.5 rounded-sm">HP</span>
                                        <span class="text-slate-700 dark:text-slate-350">{{ g.no_hp }}</span>
                                    </div>
                                    <div class="flex items-center gap-1.5" v-if="g.email">
                                        <span class="text-[10px] font-bold bg-sky-50 dark:bg-sky-950/40 text-sky-600 dark:text-sky-400 px-1 py-0.5 rounded-sm">EMAIL</span>
                                        <span class="text-slate-700 dark:text-slate-350">{{ g.email }}</span>
                                    </div>
                                    <span class="text-xs text-slate-400 italic" v-if="!g.no_hp && !g.email">Tidak ada kontak</span>
                                </div>
                            </td>

                            <!-- Status Akun -->
                            <td class="px-6 py-4">
                                <span 
                                    v-if="g.user_id" 
                                    class="text-[10px] font-black bg-emerald-50 text-emerald-700 border border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-900/50 px-2 py-0.5 rounded-md"
                                >
                                    BISA LOGIN
                                </span>
                                <span 
                                    v-else 
                                    class="text-[10px] font-black bg-slate-100 text-slate-500 border border-slate-200 dark:bg-slate-900/50 dark:text-slate-450 dark:border-slate-800/80 px-2 py-0.5 rounded-md"
                                >
                                    HANYA DATA
                                </span>
                            </td>

                            <!-- Aksi -->
                            <td class="px-6 py-4">
                                <div class="flex items-center gap-2">
                                    <!-- Edit -->
                                    <button 
                                        @click="openEditModal(g)"
                                        class="p-1.5 rounded-lg border border-blue-100 dark:border-blue-900/40 hover:bg-blue-50 dark:hover:bg-blue-950/50 text-blue-600 dark:text-blue-400 hover:text-blue-800 transition"
                                        title="Ubah Guru BK"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                        </svg>
                                    </button>

                                    <!-- Delete -->
                                    <button 
                                        @click="openDeleteModal(g)"
                                        class="p-1.5 rounded-lg border border-red-100 dark:border-red-900/40 hover:bg-red-50 dark:hover:bg-red-950/50 text-red-600 dark:text-red-400 hover:text-red-800 transition"
                                        title="Hapus Guru BK"
                                    >
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-4v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                        </svg>
                                    </button>
                                </div>
                            </td>
                        </tr>

                        <!-- Empty State -->
                        <tr v-if="!guruBks.data || guruBks.data.length === 0">
                            <td colspan="6" class="px-6 py-12 text-center">
                                <div class="flex flex-col items-center justify-center gap-3">
                                    <div class="h-12 w-12 rounded-2xl bg-blue-50 dark:bg-blue-950/40 flex items-center justify-center text-blue-500">
                                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                    </div>
                                    <h4 class="font-bold text-slate-800 dark:text-slate-200">Guru BK tidak ditemukan</h4>
                                    <p class="text-xs text-slate-400 max-w-[280px]">Mulai dengan menambahkan data Guru BK ke dalam sistem.</p>
                                </div>
                            </td>
                        </tr>
                    </Table>

                    <!-- Pagination -->
                    <div class="mt-6 flex items-center justify-between" v-if="guruBks.links && guruBks.links.length > 3">
                        <span class="text-xs text-slate-400 font-semibold">
                            Menampilkan {{ guruBks.from || 0 }} - {{ guruBks.to || 0 }} dari {{ guruBks.total }} Guru BK
                        </span>
                        <div class="flex items-center gap-1.5">
                            <button 
                                v-for="link in guruBks.links" 
                                :key="link.label"
                                @click="link.url ? router.get(link.url) : null"
                                class="px-3 py-1.5 rounded-lg border text-xs font-semibold transition"
                                :class="[
                                    link.active 
                                        ? 'bg-blue-600 text-white border-blue-600 shadow-sm' 
                                        : link.url 
                                            ? 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-350 border-gray-200 dark:border-gray-800 hover:bg-slate-50 dark:hover:bg-slate-850'
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

        <!-- ================= ADD GURU BK MODAL ================= -->
        <div v-if="showAddModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-md w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-blue-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Tambah Guru BK</h3>
                    <button @click="closeAddModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <form @submit.prevent="submitAdd" class="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
                    <!-- Nama Lengkap -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nama Lengkap <span class="text-red-500">*</span></label>
                        <input v-model="addForm.nama" type="text" placeholder="Nama Lengkap dengan Gelar..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.nama ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.nama">{{ addForm.errors.nama }}</p>
                    </div>

                    <!-- NIP -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NIP (Nomor Induk Pegawai)</label>
                        <input v-model="addForm.nip" type="text" placeholder="Contoh: 198203112009031002..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.nip ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.nip">{{ addForm.errors.nip }}</p>
                    </div>

                    <!-- Gender -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-2">Jenis Kelamin <span class="text-red-500">*</span></label>
                        <div class="flex items-center gap-6">
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="addForm.jenis_kelamin" value="L" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Laki-laki</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="addForm.jenis_kelamin" value="P" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Perempuan</span>
                            </label>
                        </div>
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.jenis_kelamin">{{ addForm.errors.jenis_kelamin }}</p>
                    </div>

                    <!-- No HP -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nomor WhatsApp/HP</label>
                        <input v-model="addForm.no_hp" type="text" placeholder="Contoh: 08123456789..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.no_hp ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.no_hp">{{ addForm.errors.no_hp }}</p>
                    </div>

                    <!-- Email -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Alamat Email</label>
                        <input v-model="addForm.email" type="email" placeholder="Contoh: gurubk@sekolah.sch.id..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="addForm.errors.email ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.email">{{ addForm.errors.email }}</p>
                    </div>

                    <!-- Toggle Create Login Account -->
                    <div class="pt-2">
                        <label class="flex items-start gap-2.5 cursor-pointer">
                            <input 
                                type="checkbox" 
                                v-model="addForm.create_account" 
                                class="mt-1 text-blue-600 focus:ring-blue-500 border-gray-350 dark:border-slate-800 dark:bg-slate-900 rounded-sm" 
                            />
                            <div>
                                <span class="block text-sm font-bold text-slate-800 dark:text-white">Buat Akun Akses Login</span>
                                <span class="block text-[11px] text-slate-400 leading-normal">Guru BK ini akan bisa masuk ke dalam sistem menggunakan email di atas.</span>
                            </div>
                        </label>
                    </div>

                    <!-- Password Field (Conditional) -->
                    <div v-if="addForm.create_account" class="space-y-4 pt-2 border-t border-gray-100 dark:border-slate-900 animate-in slide-in-from-top-2 duration-150">
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Kata Sandi (Password) <span class="text-red-500">*</span></label>
                            <input v-model="addForm.password" type="password" placeholder="Minimal 8 Karakter..." required
                                class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="addForm.errors.password ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="addForm.errors.password">{{ addForm.errors.password }}</p>
                        </div>
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
                            {{ addForm.processing ? 'Menyimpan...' : 'Simpan Guru BK' }}
                        </PrimaryButton>
                    </div>
                </form>
            </div>
        </div>

        <!-- ================= EDIT GURU BK MODAL ================= -->
        <div v-if="showEditModal" class="fixed inset-0 z-50 overflow-y-auto flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
            <div class="bg-white dark:bg-slate-950 rounded-2xl border border-slate-200 dark:border-slate-850 max-w-md w-full overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
                <div class="px-6 py-4 border-b border-gray-100 dark:border-slate-900 flex justify-between items-center bg-gradient-to-r from-blue-50/50 to-sky-50/50 dark:from-slate-900/50 dark:to-slate-900/50">
                    <h3 class="font-extrabold text-slate-900 dark:text-white text-lg">Ubah Guru BK</h3>
                    <button @click="closeEditModal" class="p-1 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900 hover:text-slate-900 dark:hover:text-white transition">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
                        </svg>
                    </button>
                </div>

                <form @submit.prevent="submitEdit" class="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
                    <!-- Nama Lengkap -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nama Lengkap <span class="text-red-500">*</span></label>
                        <input v-model="editForm.nama" type="text" placeholder="Nama Lengkap dengan Gelar..." required
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.nama ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.nama">{{ editForm.errors.nama }}</p>
                    </div>

                    <!-- NIP -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">NIP (Nomor Induk Pegawai)</label>
                        <input v-model="editForm.nip" type="text" placeholder="Contoh: 198203112009031002..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.nip ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.nip">{{ editForm.errors.nip }}</p>
                    </div>

                    <!-- Gender -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-2">Jenis Kelamin <span class="text-red-500">*</span></label>
                        <div class="flex items-center gap-6">
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="editForm.jenis_kelamin" value="L" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Laki-laki</span>
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-350 cursor-pointer">
                                <input type="radio" v-model="editForm.jenis_kelamin" value="P" class="text-blue-600 focus:ring-blue-500 border-gray-300 dark:border-slate-800 dark:bg-slate-900" />
                                <span>Perempuan</span>
                            </label>
                        </div>
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.jenis_kelamin">{{ editForm.errors.jenis_kelamin }}</p>
                    </div>

                    <!-- No HP -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Nomor WhatsApp/HP</label>
                        <input v-model="editForm.no_hp" type="text" placeholder="Contoh: 08123456789..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.no_hp ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.no_hp">{{ editForm.errors.no_hp }}</p>
                    </div>

                    <!-- Email -->
                    <div>
                        <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Alamat Email</label>
                        <input v-model="editForm.email" type="email" placeholder="Contoh: gurubk@sekolah.sch.id..."
                            class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                            :class="editForm.errors.email ? 'border-red-500' : 'border-gray-200'"
                        />
                        <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.email">{{ editForm.errors.email }}</p>
                    </div>

                    <!-- Account Management Panel -->
                    <div v-if="editForm.has_account" class="pt-4 border-t border-gray-100 dark:border-slate-900 space-y-4">
                        <div class="flex items-center gap-2 text-xs font-black text-slate-500 uppercase tracking-wide">
                            <span class="h-2 w-2 rounded-full bg-emerald-500"></span>
                            <span>Akses Login Aktif</span>
                        </div>
                        <div>
                            <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Ubah Kata Sandi (Kosongkan jika tidak diubah)</label>
                            <input v-model="editForm.password" type="password" placeholder="Masukkan Sandi Baru..."
                                class="w-full text-sm py-2 px-3 rounded-lg border border-gray-200 dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                :class="editForm.errors.password ? 'border-red-500' : 'border-gray-200'"
                            />
                            <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.password">{{ editForm.errors.password }}</p>
                        </div>
                    </div>

                    <div v-else class="pt-4 border-t border-gray-100 dark:border-slate-900 space-y-4">
                        <!-- Toggle Create Login Account -->
                        <div>
                            <label class="flex items-start gap-2.5 cursor-pointer">
                                <input 
                                    type="checkbox" 
                                    v-model="editForm.create_account" 
                                    class="mt-1 text-blue-600 focus:ring-blue-500 border-gray-350 dark:border-slate-800 dark:bg-slate-900 rounded-sm" 
                                />
                                <div>
                                    <span class="block text-sm font-bold text-slate-800 dark:text-white">Aktifkan Akses Login</span>
                                    <span class="block text-[11px] text-slate-400 leading-normal">Guru BK ini belum memiliki akun. Centang ini untuk membuatkan akun.</span>
                                </div>
                            </label>
                        </div>

                        <!-- Password Field (Conditional during edit) -->
                        <div v-if="editForm.create_account" class="space-y-4 pt-2 border-t border-gray-100 dark:border-slate-900 animate-in slide-in-from-top-2 duration-150">
                            <div>
                                <label class="block text-xs font-black text-slate-500 uppercase tracking-wide mb-1">Kata Sandi (Password) <span class="text-red-500">*</span></label>
                                <input v-model="editForm.password" type="password" placeholder="Minimal 8 Karakter..." required
                                    class="w-full text-sm py-2 px-3 rounded-lg border dark:border-slate-800 bg-transparent focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                                    :class="editForm.errors.password ? 'border-red-500' : 'border-gray-200'"
                                />
                                <p class="text-[10px] text-red-500 mt-1" v-if="editForm.errors.password">{{ editForm.errors.password }}</p>
                            </div>
                        </div>
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
                            {{ editForm.processing ? 'Menyimpan...' : 'Perbarui Guru BK' }}
                        </PrimaryButton>
                    </div>
                </form>
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
                
                <h3 class="text-base font-extrabold text-slate-900 dark:text-white mb-2">Hapus Data Guru BK?</h3>
                <p class="text-xs text-slate-400 mb-6 leading-relaxed">
                    Apakah Anda yakin ingin menghapus data Guru BK <strong>{{ selectedGuruBk?.nama }}</strong>? Jika guru ini memiliki akun login, akun login tersebut juga akan terhapus. Tindakan ini bersifat permanen.
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
