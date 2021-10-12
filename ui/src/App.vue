<template>
  <div class="dark flex flex-col h-full">
    <div class="flex items-center">
      <img class="m-2" alt="REPL-LOOPER logo" src="./assets/logo-dark.png" width="50" />
      <h1 class="text-3xl m-2">REPL-LOOPER</h1>
      <button @click="toggleDark">Toggle</button>
    </div>
    <REPL />
  </div>
</template>

<script>
import REPL from './components/REPL.vue';
import nightwind from "nightwind/helper";

export default {
  components: {
    REPL
  },
  mounted() {
    nightwind.init();
    nightwind.enable(true);
  },
  methods: {
    toggleDark() {
      console.log("Toggling", nightwind);
      nightwind.toggle();
    }
  },
};
</script>

<style>

</style>
