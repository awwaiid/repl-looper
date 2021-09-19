<template>
  <div v-for="line in history">
    {{ line }}
  </div>
  Input: <input type=text @change="gotInput" v-model="currentInput" />
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
  history.value.push(data);
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

