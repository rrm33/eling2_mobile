<script setup>
import { onMounted, ref } from 'vue';

const model = defineModel({
    required: true,
});

const props = defineProps({
    options: {
        type: Array,
        default: () => [],
        // Options format: [{ value: '...', label: '...' }] or strings
    },
    placeholder: {
        type: String,
        default: 'Pilih salah satu...',
    }
});

const input = ref(null);

onMounted(() => {
    if (input.value.hasAttribute('autofocus')) {
        input.value.focus();
    }
});

defineExpose({ focus: () => input.value.focus() });
</script>

<template>
    <select
        class="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:focus:border-blue-600 dark:focus:ring-blue-600 w-full py-2 px-3 transition duration-150 ease-in-out cursor-pointer"
        v-model="model"
        ref="input"
    >
        <option value="" disabled selected>{{ placeholder }}</option>
        <option 
            v-for="option in options" 
            :key="typeof option === 'object' ? option.value : option" 
            :value="typeof option === 'object' ? option.value : option"
        >
            {{ typeof option === 'object' ? option.label : option }}
        </option>
    </select>
</template>
