<script setup>
import { computed } from 'vue';

const props = defineProps({
    type: {
        type: String,
        default: 'neutral', // success, danger, warning, info, primary, neutral
    },
});

const badgeClasses = computed(() => {
    const base = 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold font-medium transition duration-150 ease-in-out select-none shadow-xs';
    
    const types = {
        primary: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300 border border-blue-200/50 dark:border-blue-800/50',
        success: 'bg-sky-100 text-sky-800 dark:bg-sky-900/30 dark:text-sky-300 border border-sky-200/50 dark:border-sky-800/50',
        danger: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300 border border-red-200/50 dark:border-red-800/50',
        warning: 'bg-sky-100 text-sky-800 dark:bg-sky-900/30 dark:text-sky-300 border border-sky-200/50 dark:border-sky-800/50',
        info: 'bg-sky-100 text-sky-800 dark:bg-sky-900/30 dark:text-sky-300 border border-sky-200/50 dark:border-sky-800/50',
        neutral: 'bg-slate-100 text-slate-800 dark:bg-slate-850 dark:text-slate-300 border border-slate-200/50 dark:border-slate-800/50',
    };

    return `${base} ${types[props.type] || types.neutral}`;
});
</script>

<template>
    <span :class="badgeClasses">
        <slot />
    </span>
</template>
