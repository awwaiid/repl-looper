<template>
  <div class="flex flex-col h-full bg-black text-white">
    <div class="flex items-center">
      <img class="m-2" alt="REPL-LOOPER logo" src="./assets/logo-dark.png" width="50" />
      <h1 class="text-3xl m-2">REPL-LOOPER</h1>
    </div>
    <REPL />
  </div>
</template>

<script>
import REPL from './components/REPL.vue';
// import nightwind from "nightwind/helper";

export default {
  components: {
    REPL
  },
  mounted() {
    // nightwind.init();
    // nightwind.enable(true);
  },
};
</script>

<style>

</style>
