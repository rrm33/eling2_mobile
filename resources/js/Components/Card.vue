<script setup>
defineProps({
    hoverable: {
        type: Boolean,
        default: false,
    },
    variant: {
        type: String,
        default: 'default', // default, glass, primary, gradient, indigo, rose, emerald, sky
    }
});
</script>

<template>
    <div
        class="overflow-hidden rounded-xl transition-all duration-300"
        :class="[
            hoverable ? 'hover:-translate-y-1 hover:shadow-lg' : '',
            
            // Standard variants
            variant === 'default' ? 'bg-white border border-gray-200 shadow-xs dark:border-gray-800 dark:bg-gray-900' : '',
            variant === 'glass' ? 'border border-gray-200/50 bg-white/80 dark:border-gray-800/50 dark:bg-gray-950/80 backdrop-blur-md shadow-xs' : '',
            variant === 'primary' ? 'border border-blue-150 dark:border-blue-900/50 bg-blue-50/20 dark:bg-blue-950/10 shadow-xs' : '',
            variant === 'gradient' ? 'bg-gradient-to-br from-blue-500/5 to-sky-500/5 dark:from-blue-500/10 dark:to-sky-500/10 border border-blue-200/50 dark:border-blue-800/40 shadow-xs' : '',
            
            // Solid Color Gradients
            variant === 'indigo' ? 'bg-gradient-to-br from-blue-500 via-blue-600 to-sky-600 text-white shadow-md shadow-blue-500/20' : '',
            variant === 'purple' ? 'bg-gradient-to-br from-sky-500 via-sky-600 to-sky-700 text-white shadow-md shadow-sky-500/20' : '',
            variant === 'blue' ? 'bg-gradient-to-br from-blue-500 via-blue-600 to-blue-700 text-white shadow-md shadow-blue-500/20' : '',
            variant === 'sky' ? 'bg-gradient-to-br from-sky-400 via-sky-500 to-blue-600 text-white shadow-md shadow-sky-500/20' : '',
        ]"
    >
        <!-- Card Header -->
        <div 
            v-if="$slots.header" 
            class="px-6 py-4 border-b transition-colors duration-300"
            :class="[
                ['indigo', 'purple', 'blue', 'sky'].includes(variant) 
                    ? 'border-white/10 text-white' 
                    : 'border-gray-150 dark:border-gray-800 text-slate-900 dark:text-white'
            ]"
        >
            <slot name="header" />
        </div>

        <!-- Card Body -->
        <div class="p-6">
            <slot />
        </div>

        <!-- Card Footer -->
        <div 
            v-if="$slots.footer" 
            class="px-6 py-4 border-t transition-colors duration-300"
            :class="[
                ['indigo', 'purple', 'blue', 'sky'].includes(variant) 
                    ? 'border-white/10 bg-black/10' 
                    : 'border-gray-150 bg-gray-50/50 dark:border-gray-800 dark:bg-gray-950/20'
            ]"
        >
            <slot name="footer" />
        </div>
    </div>
</template>
