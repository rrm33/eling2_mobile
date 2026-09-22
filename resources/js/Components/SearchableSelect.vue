<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';

const props = defineProps({
    options: {
        type: Array,
        required: true, // Array of { value: any, label: string, info?: string }
    },
    modelValue: {
        type: [String, Number, null],
        default: null,
    },
    placeholder: {
        type: String,
        default: 'Pilih opsi...',
    },
    disabled: {
        type: Boolean,
        default: false,
    },
    error: {
        type: String,
        default: '',
    }
});

const emit = defineEmits(['update:modelValue', 'change']);

const isOpen = ref(false);
const search = ref('');
const rootRef = ref(null);

const selectedOption = computed(() => {
    return props.options.find(opt => opt.value === props.modelValue) || null;
});

const filteredOptions = computed(() => {
    if (!search.value) return props.options;
    const term = search.value.toLowerCase();
    return props.options.filter(opt => 
        opt.label.toLowerCase().includes(term) || 
        (opt.info && opt.info.toLowerCase().includes(term))
    );
});

const toggleDropdown = () => {
    if (props.disabled) return;
    isOpen.value = !isOpen.value;
    if (isOpen.value) {
        search.value = '';
    }
};

const selectOption = (opt) => {
    emit('update:modelValue', opt.value);
    emit('change', opt.value);
    isOpen.value = false;
};

// Close when clicking outside
const handleClickOutside = (event) => {
    if (rootRef.value && !rootRef.value.contains(event.target)) {
        isOpen.value = false;
    }
};

onMounted(() => {
    document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
    document.removeEventListener('click', handleClickOutside);
});

// Focus the search input when dropdown opens
const searchInputRef = ref(null);
watch(isOpen, (newVal) => {
    if (newVal) {
        setTimeout(() => {
            if (searchInputRef.value) {
                searchInputRef.value.focus();
            }
        }, 50);
    }
});
</script>

<template>
    <div ref="rootRef" class="relative w-full text-left">
        <!-- Trigger Button -->
        <button
            type="button"
            @click="toggleDropdown"
            :disabled="disabled"
            class="w-full text-sm py-2 px-3 rounded-lg border bg-white dark:bg-slate-900 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white flex items-center justify-between transition duration-150 cursor-pointer disabled:bg-slate-50 dark:disabled:bg-slate-950 disabled:text-slate-400 disabled:cursor-not-allowed"
            :class="[
                error ? 'border-red-500 ring-1 ring-red-500' : 'border-gray-200 dark:border-slate-800',
                disabled ? 'opacity-70' : 'hover:border-gray-300 dark:hover:border-slate-700'
            ]"
        >
            <div class="truncate pr-2">
                <span v-if="selectedOption" class="font-medium text-slate-800 dark:text-white">
                    {{ selectedOption.label }}
                    <span v-if="selectedOption.info" class="text-xs text-slate-400 font-normal ml-1">
                        ({{ selectedOption.info }})
                    </span>
                </span>
                <span v-else class="text-slate-450 dark:text-slate-500">
                    {{ placeholder }}
                </span>
            </div>
            <div class="flex items-center text-slate-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 transition-transform duration-200" :class="{ 'rotate-180': isOpen }" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                </svg>
            </div>
        </button>

        <!-- Dropdown Menu -->
        <div
            v-if="isOpen"
            class="absolute z-50 mt-1.5 w-full bg-white dark:bg-slate-950 border border-slate-200 dark:border-slate-850 rounded-xl shadow-2xl overflow-hidden animate-in fade-in slide-in-from-top-1 duration-100"
        >
            <!-- Search Input Inside Dropdown -->
            <div class="p-2 border-b border-slate-100 dark:border-slate-900 bg-slate-50/50 dark:bg-slate-950">
                <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                    </div>
                    <input
                        ref="searchInputRef"
                        v-model="search"
                        type="text"
                        placeholder="Ketik untuk mencari..."
                        class="w-full pl-10 pr-3 py-1.5 text-xs bg-white dark:bg-slate-900 border border-gray-200 dark:border-gray-800 rounded-lg focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-hidden dark:text-white placeholder-slate-400"
                    />
                </div>
            </div>

            <!-- Options List -->
            <ul class="max-h-60 overflow-y-auto py-1">
                <li
                    v-for="opt in filteredOptions"
                    :key="opt.value"
                    @click="selectOption(opt)"
                    class="px-3.5 py-2 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-blue-600 hover:text-white dark:hover:bg-blue-600 dark:hover:text-white cursor-pointer transition duration-100 flex flex-col gap-0.5"
                    :class="{ 'bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-400': opt.value === modelValue }"
                >
                    <span class="truncate">{{ opt.label }}</span>
                    <span v-if="opt.info" class="text-[10px] text-slate-400 font-normal group-hover:text-white/80">
                        {{ opt.info }}
                    </span>
                </li>

                <!-- Empty State -->
                <li v-if="filteredOptions.length === 0" class="px-3.5 py-4 text-xs text-center text-slate-450 dark:text-slate-500 italic">
                    Tidak ada hasil ditemukan
                </li>
            </ul>
        </div>
    </div>
</template>
