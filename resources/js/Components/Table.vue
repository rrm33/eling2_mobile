<script setup>
defineProps({
    headers: {
        type: Array,
        required: true,
        // Format: ['Nama Siswa', 'Kelas', 'Kasus', 'Status', 'Aksi'] or objects { label: '...', align: 'left/right/center' }
    },
});
</script>

<template>
    <div class="w-full overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-xs dark:border-gray-800 dark:bg-gray-900 transition-all duration-300">
        <table class="w-full min-w-full table-auto border-collapse text-left text-sm text-gray-500 dark:text-gray-400">
            <!-- Table Header -->
            <thead class="bg-gray-50/75 text-xs font-semibold uppercase text-gray-700 dark:bg-gray-850 dark:text-gray-300 border-b border-gray-200 dark:border-gray-800 select-none">
                <tr>
                    <th
                        v-for="(header, index) in headers"
                        :key="index"
                        class="px-6 py-4 font-semibold tracking-wider"
                        :class="[
                            typeof header === 'object' && header.align === 'right' ? 'text-right' : '',
                            typeof header === 'object' && header.align === 'center' ? 'text-center' : '',
                            typeof header === 'object' && header.align === 'left' ? 'text-left' : '',
                        ]"
                    >
                        {{ typeof header === 'object' ? header.label : header }}
                    </th>
                </tr>
            </thead>

            <!-- Table Body -->
            <tbody class="divide-y divide-gray-150 dark:divide-gray-800 bg-white dark:bg-gray-900">
                <slot />
                <tr v-if="!$slots.default" class="text-center">
                    <td :colspan="headers.length" class="px-6 py-10 text-gray-400 dark:text-gray-500">
                        Tidak ada data ditemukan.
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</template>
