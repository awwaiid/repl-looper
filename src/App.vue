<template>
  <div class="flex flex-col h-full">
    <div class="flex items-center">
      <img alt="REPL-LOOPER logo" src="./assets/logo.png" width="50" />
      <h1>REPL-LOOPER</h1>
    </div>
    <REPL />
  </div>
</template>

<script>
import HelloWorld from './components/HelloWorld.vue';
import REPL from './components/REPL.vue';

export default {
  components: {
    HelloWorld,
    REPL
  }
};
</script>

<style>

</style>
