<template>
  <div class="flex flex-col h-full min-h-0 border-2 border-grey-10 m-2 p-2">
    <div class="overflow-y-auto flex-grow min-h-0" id="messages">
      <div v-for="line in history" class="line">
        <pre>{{ line.trimEnd() }}</pre>
      </div>
    </div>
    <div class="border-grey-20 border-t-2 p-1 w-full flex-none flex items-center">
      <div>Input:</div>
      <div class="flex-grow w-full border-4 border-grey-50">
        <input class="w-full" type=text @change="gotInput" v-model="currentInput" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick } from 'vue';

const currentInput = ref("");
const history = ref([]);

console.log("Starting connection to WebSocket Server");
const norns = new WebSocket("ws://norns.local:5555/",["bus.sp.nanomsg.org"]);

norns.onmessage = async function(event) {
  console.log("got message", event);
  const data = event.data;
  history.value.push("→ " + data);

  // Scroll to the bottom!
  await nextTick(); // Need the new DOM node to be done
  const element = document.querySelector("#messages .line:last-child");
  element.scrollIntoView({behavior: "smooth", block: "end"});
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

