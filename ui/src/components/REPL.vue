<template>
  <div class="flex flex-col h-full min-h-0 border-2 border-grey-10 m-2 p-2">
    <div class="flex flex-row">
      <div v-for="step in playbackStepCount">
        <div v-if="playbackStep + 1 === step">
          &#9635;
        </div>
        <div v-else>
          &#9633;
        </div>
      </div>
    </div>

    <div class="overflow-y-auto flex-grow min-h-0" id="messages">
      <div v-for="line in history" class="line">
        <pre>{{ line.trimEnd() }}</pre>
      </div>
    </div>

    <!-- <div> -->
    <!--   <pre>{{ recording }}</pre> -->
    <!-- </div> -->

    <div class="border-grey-20 border-t-2 p-1 w-full flex-none flex items-center">
      <div>Input:</div>
      <div class="flex-grow w-full border-2">
        <input class="w-full bg-black text-white" type=text @keydown.enter="gotInput" v-model="currentInput" />
      </div>
      <button
        v-show="!recording.currentlyRecording"
        @click="startRecording"
      >
        Rec
      </button>
      <button
        v-show="recording.currentlyRecording"
        @click="stopRecording"
      >
        Stop
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick, reactive } from 'vue';

const currentInput = ref("");
const history = ref([]);
const currentLoop = ref([]);
const connected = ref(false);
const recording = reactive({
  currentlyRecording: false,
  loopNum: 1,
  startTime: 0,
  endTime: 0,
  events: []
});
const playbackStep = ref(0);
const playbackStepCount = ref(16);

console.log("Starting connection to WebSocket Server");
const norns = new WebSocket("ws://norns.local:5555/",["bus.sp.nanomsg.org"]);
// const norns = new WebSocket("ws://localhost:5555/");

async function scrollMessagesToBottom() {
  // Scroll to the bottom!
  await nextTick(); // Need the new DOM node to be done
  const element = document.querySelector("#messages .line:last-child");
  element.scrollIntoView({behavior: "smooth", block: "end"});
}

norns.onmessage = async (event) => {
  console.log("got message", event);
  const data = event.data;
  let m = data.match(/SERVER MESSAGE: (.*)/);
  if (m) {
    let serverMessage = JSON.parse(m[1]);
    console.log("msg: ", serverMessage);
    if (serverMessage.action == "playback_step") {
      playbackStep.value = parseInt(serverMessage.step);
      playbackStepCount.value = Math.ceil(parseFloat(serverMessage.stepCount));
    }
  } else {
    history.value.push("→ " + data);
    scrollMessagesToBottom();
  }
};

norns.onopen = (event) => {
  console.log("on open", event)
  console.log("Successfully connected to the echo websocket server...")
  connected.value = true;
};

norns.onclose = () => {
  connected.value = false;
}

async function gotInput(v) {
  console.log("gotInput", { v });
  const command = v.target.value;
  history.value.push(command);
  scrollMessagesToBottom();
  currentInput.value = "";

  if(command === "rec") {
    startRecording();
    return;
  }

  if(command === "stop") {
    stopRecording();
    return;
  }

  if(recording.currentlyRecording) {
    const currentTime = Date.now();
    recording.events.push({
      absoluteTime: currentTime,
      relativeTime: currentTime - recording.startTime,
      command
    });
    console.log({ recording });
  }

  console.log(`Sending to norns [${command}]`);
  norns.send(command + "\n");
  // norns.send(command);
}

function startRecording(loopNum = 1) {
  recording.currentlyRecording = true;
  recording.loopNum = loopNum;
  recording.startTime = Date.now();
  recording.endTime = null;
  recording.events = [];
}

function stopRecording() {
  recording.currentlyRecording = false;
  recording.endTime = Date.now();
  recording.duration = recording.endTime - recording.startTime;
  const jsonRecording = JSON.stringify(JSON.stringify({
    command: "save_loop",
    loop_num: recording.loopNum || 1,
    loop: recording
  }));
  console.log(`JSON: ${jsonRecording}`);
  console.log('SEND: messageToServer("' + jsonRecording + '"' + ")\n");
  norns.send('messageToServer(' + jsonRecording + ")\n");
}


</script>

