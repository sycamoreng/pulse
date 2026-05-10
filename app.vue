<template>
  <div>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
    <Toaster />
    <ConfirmDialog />
  </div>
</template>

<script setup lang="ts">
useHead({
  script: [
    {
      innerHTML: `(function(){try{var t=localStorage.getItem('pulse.theme');if(t!=='light'&&t!=='dark')t='dark';if(t==='dark')document.documentElement.classList.add('dark');document.documentElement.style.colorScheme=t;}catch(e){document.documentElement.classList.add('dark');}})();`,
      tagPosition: 'bodyOpen',
    },
  ],
  htmlAttrs: { class: 'dark' },
})
</script>
