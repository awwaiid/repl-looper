<template>
  <div class="flex flex-col h-full min-h-0 border-2 border-grey-10 m-2 p-2">

    <div class="flex flex-col m-0 p-0 border-grey-10">
      <div class="flex flex-row border-grey-10" v-for="(loop, loop_id) in playbackStepCount">
        <div v-for="step in playbackStepCount[loop_id]">
          <div v-if="playbackStep[loop_id] === step" style="width: 10px; height: 10px" class="bg-white">
          </div>
          <div v-else style="width: 10px; height: 10px">
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-3 min-h-0">

      <div class="col-span-2 overflow-y-scroll overflow-x-hidden" id="messages" style="-webkit-scrollbar-color: black black">
        <div v-for="line, lineNum in history" class="line">
          <pre :class="{ historySelected: offset == lineNum, historyNotSelected: offset !== lineNum }">{{ line.trimEnd() }}</pre>
        </div>
      </div>

      <div class="flex-1 overflow-y-scroll overflow-x-scroll text-red-400 text-xs" id="server-messages">
        <div v-for="line, lineNum in serverHistory" class="line">
          <pre>{{ line.trimEnd() }}</pre>
        </div>
      </div>

    </div>

    <div class="border-grey-20 border-t-2 p-1 w-full flex-none flex items-center">
      <div class="flex-grow w-full border-2">
        <textarea
          id="command-input"
          class="w-full bg-black text-white"
          type=text
          rows=5
          @keydown.enter.exact.prevent="gotInput"
          @keydown.arrow-up.exact.prevent="historyUp"
          @keydown.arrow-down.exact.prevent="historyDown"
          @keydown.tab.prevent="requestCompletions"
          v-model="currentInput" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick, reactive } from 'vue';

function js2lua(obj, indentation) {
    var whitespace = 1;
    // Setup whitespace
    if (indentation && typeof indentation === 'number') whitespace = indentation, indentation = '';

    // Get type of obj
    var type = typeof obj;

    // Handle type
    if (~['number', 'boolean'].indexOf(type)) {
        return obj;
    } else if (type === 'string') {
        return '"' + escapeLuaString(obj) + '"';
    } else if (type === 'undefined' || obj === null) {
        // Return 'nil' for null || undefined
        return 'nil';
    } else {
        // Object
        // Increase indentation
        for (var i = 0, previous = indentation || '', indentation = indentation || ''; i < whitespace; indentation += ' ', i++);

        // Check if array
        if (Array.isArray(obj)) {
            // Convert each item in array, checking for whitespace
      if (whitespace && obj.length > 2) return '{\n' + indentation + obj.map(function (prop) { return js2lua(prop, indentation); }).join(',\n' + indentation) + '\n' + previous + '}';
            else return '{' + obj.map(function (prop) { return js2lua(prop); }).join(', ') + '}';
        } else {
            // Build out each property
            var props = [];
            for (var key in obj) {
                props.push(key + (whitespace ? ' = ' + js2lua(obj[key], indentation) : ' = ' + js2lua(obj[key])));
            }

            // Join properties && return
      if (whitespace && props.length > 2) { return '{\n' + indentation + props.join(',\n' + indentation) + '\n' + previous + '}'; }
            else return '{' + props.join(', ') + '}';
        }
    }
}

// ### escapeLuaString
// Escape string for serialization to lua object
//
// * `str`: string to escape
function escapeLuaString(str) {
    return str
        .replace(/\n/g,'\\n')
        .replace(/\r/g,'\\r')
        .replace(/"/g,'\\"')
        .replace(/\\$/g, '\\\\');
}



const currentInput = ref("");
const history = ref([]);
const serverHistory = ref([]);
const connected = ref(false);
const playbackStep = ref([]);
const playbackStepCount = ref([]);

console.log("Starting connection to WebSocket Server");
const norns = new WebSocket("ws://norns.local:5555/",["bus.sp.nanomsg.org"]);

function longestPrefix(words){
  // check border cases size 1 array and empty first word)
  if (!words[0] || words.length ==  1) return words[0] || "";
  let i = 0;
  // while all words have the same character at position i, increment i
  while(words[0][i] && words.every(w => w[i] === words[0][i]))
    i++;

  // prefix is the substring from the beginning to the last successfully checked i
  return words[0].substr(0, i);
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
    return;
  }

  m = data.match(/RESPONSE:(.*)/);
  if (m) {
    let serverMessage = JSON.parse(m[1]);
    console.log("msg: ", serverMessage);
    if (serverMessage.action == "live_event" && serverMessage.result !== undefined) {
      // history.value.push(">> [" + serverMessage.result + "]");
      console.log("JS2LUA:",
        "[" + js2lua(serverMessage.result, null, 2) + "]",
        typeof(js2lua(serverMessage.result, null, 2))
      );
      // history.value.push(JSON.stringify(serverMessage.result, null, 2));
      history.value.push(String(js2lua(serverMessage.result, null, 2)));
      await scrollMessagesToBottom();
    } else if (serverMessage.action == "completions"
        && serverMessage.result !== undefined
        && serverMessage.result.length > 0
        && Array.isArray(serverMessage.result)) {
      console.log("completions:", serverMessage.result);

      if(serverMessage.result.length > 1) {
        serverMessage.result.forEach( completion => {
          history.value.push(completion)
        });
      }

      currentInput.value = longestPrefix(serverMessage.result);
      cursorToEnd();

      await scrollMessagesToBottom();
    }
    return;
  }

  // history.value = history.value.slice(1,20)
  const trimmedData = data.trim()
  if (trimmedData) {
    serverHistory.value.push("→ [" + trimmedData + "]");
    await scrollServerMessagesToBottom();
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

async function scrollServerMessagesToBottom() {
  // Scroll to the bottom!
  await nextTick(); // Need the new DOM node to be done
  const element = document.querySelector("#server-messages .line:last-child");
  console.log("scrolling to bottom to", element);
  // element.scrollIntoView({behavior: "smooth", block: "nearest"});
  element.scrollIntoView({block: "nearest"});
}

async function scrollMessagesToBottom() {
  // Scroll to the bottom!
  await nextTick(); // Need the new DOM node to be done
  const element = document.querySelector("#messages .line:last-child");
  console.log("scrolling to bottom to", element);
  // element.scrollIntoView({behavior: "smooth", block: "nearest"});
  if (element) {
    element.scrollIntoView({block: "end"});
  }
}

async function scrollMessagesToSelected() {
  await nextTick(); // Need the new DOM node to be done
  const element = document.querySelector("#messages .line .historySelected");
  console.log("Srolling to", element);
  // element.scrollIntoView({behavior: "smooth", block: "nearest"});
  element.scrollIntoView({ block: 'nearest' }); // {behavior: "smooth", block: "nearest"});
}

function cursorToEnd() {
  const element = document.querySelector("#command-input");
  const len = element.value.length;
  console.log("moving cursor to end", element, len);
  element.focus();
  element.setSelectionRange(len, len);
}


let offset = ref(undefined);

async function historyUp(v) {
  console.log("historyUp", { v });
  if (!offset.value) {
    offset.value = history.value.length - 1;
  } else {
    offset.value = offset.value - 1;
    if (offset.value < 0) {
      offset.value = history.value.length - 1;
    }
  }
  currentInput.value = history.value[offset.value];
  await scrollMessagesToSelected();
  cursorToEnd();
}

async function historyDown(v) {
  console.log("historyDown", { v });
  if (offset.value == undefined) {
    offset.value = 0
  } else {
    offset.value = offset.value + 1;
    if (offset.value >= history.value.length) {
      offset.value = 0;
    }
  }
  currentInput.value = history.value[offset.value];
  await scrollMessagesToSelected();
  cursorToEnd();
}

async function gotInput(v) {
  console.log("gotInput", { v });
  let command = v.target.value;
  if(!command) {
    command = history.value[history.value.length - 1];
  }
  history.value.push(command);
  offset.value = undefined;
  await scrollMessagesToBottom();
  currentInput.value = "";

  console.log("Sending to norns: live_event(" + JSON.stringify(command) + ")\n");
  norns.send("live_event(" + JSON.stringify(command) + ")\n");
  // norns.send(command + "\n");
  // norns.send(command);
}

async function requestCompletions(v) {
  console.log("gotInput", { v });
  const command = v.target.value;

  offset.value = undefined; // Unselect from history

  console.log("Sending to norns: live_event(" + JSON.stringify(command) + ")\n");
  norns.send("completions(" + JSON.stringify(command) + ")\n");
  // norns.send(command + "\n");
  // norns.send(command);
}

</script>

<style>
  .historySelected {
    border: 1px solid white;
}
  .historyNotSelected {
    border: 1px solid black;
}

</style>
