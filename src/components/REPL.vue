<template>
  <div class="flex flex-col h-full min-h-0">
    <div class="overflow-y-scroll flex-grow min-h-0">
      <div v-for="line in history">
        <pre>{{ line.trimEnd() }}</pre>
      </div>
    </div>
    <div class="border-black border-t-4 w-full flex-none flex">
      <div>Input:</div>
      <div class="flex-grow w-full border-4 border-grey-50">
        <input class="w-full" type=text @change="gotInput" v-model="currentInput" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';

const currentInput = ref("");
const history = ref([]);

console.log("Starting connection to WebSocket Server");
const norns = new WebSocket("ws://norns.local:5555/",["bus.sp.nanomsg.org"]);

norns.onmessage = function(event) {
  console.log("got message", event);
  const data = event.data;
  history.value.push("→ " + data);
}

norns.onopen = function(event) {
  console.log("on open", event)
  console.log("Successfully connected to the echo websocket server...")
}

function gotInput(v) {
  console.log("gotInput", { v });
  const command = v.target.value;
  history.value.push(command);
  currentInput.value = "";

  norns.send(command + "\n");
}

</script>

