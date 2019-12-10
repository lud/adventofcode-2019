

export function compile(str) {
  let memory = str.split(',').map(n => parseInt(n))
  return createState(memory)
}

export function run(program, opts = {}) {
  if (typeof program === 'string') {
    program = compile(program)
  }
  if (opts.transform) {
    program.transform(opts.transform)
  }
  if (opts.input) {
    program.setInput(opts.input)
  }
  if (opts.output) {
    program.setOutput(opts.output)
  }
  return runSteps(program)
}

export function makeInputBuffer(initial = []) {
  const buffer = initial.slice()
  const input = function() {
    if (buffer.length === 0) {
      throw new Error("Buffer is empty")
    }
    const val = buffer.shift()
    console.log(`input`, val)
    return val
  }
  input.__buffer = buffer
  input.push = val => {
    buffer.push(val)
    return input
  }
  return input
}

const commands = []

function createCommand(code, exec) {
  commands[code] = { exec, nargs: exec.length - 2 }
}

function getCommand(op) {
  const { code } = op
  if (commands[code]) {
    return commands[code]
  }
  else {
    console.error("Error reading command", op)
    throw new Error(`Unknown command ${code}`)
  }
}

function runCommand(program, op, args) {
  getCommand(op).exec(program, op, ...args)
}

function argsNumber(op) {
  return getCommand(op).nargs
}

function createState(initial) {
  const memory = initial.slice()
  let cursor = 0
  let halted = false
  let exitCode
  let relativeBase = 0
  const state = { 
    setHalted: code => {
      halted = true
      exitCode = code
    },
    isHalted: () => halted,
    moveTo: n => { cursor = n },
    offsetRelative: n => {
      relativeBase += n
    },
    rel: pos => relativeBase + pos,
    pos: () => cursor,
    read: () => memory[cursor++],
    get: pos => {
      if (typeof memory[pos] === 'undefined') {
        return 0
      }
      return memory[pos]
    },
    getRel: pos => {
      return state.get(state.rel(pos))
    },
    set: (n, v) => {
      const type = typeof v
      if (type !== 'number') {
        throw new Error(`Cannot write value of type ${type} at position ${n}`)
      }
      memory[n] = v 
    }, 
    transform: fn => fn(memory),
    snapshot: () => memory.slice(),
    setInput: inp => { 
      state.input = inp
      return state
    },
    setOutput: outp => { 
      state.output = outp 
      return state
    },
    withIO: (inp, outp) => {
      state.setInput(inp)
      state.setOutput(outp)
      return state
    },
    fork: () => createState(memory),
    input: () => { throw new Error("Input not initialized") },
    output: () => { throw new Error("output not initialized") },
  }

  return state 
}

export function runSteps(program, iterations = Infinity) {
  let cursor = 0
  try {
    while (iterations-- > 0) {
      let opcode = program.read()
      let op = readOpcode(opcode)
      let args = readArgs(program, op)
      runCommand(program, op, args)
    }
  } catch (e) {
    console.log('program exit', e)
    if (e.exitCode) {
      program.setHalted(e.exitCode)
      console.error("Program error", e)
      return `Exit: ${e.exitCode}`
    } else {
      if (e.exitCode === 0) {
        program.setHalted(0)
        return program.snapshot()
      }
      console.error("Program error", e)
      throw e
    }
  }
  return program.snapshot()
}

function exit(exitCode) {
  throw { exitCode }
}

function readOpcode(opcode) {
  const str = opcode.toString().padStart(5, 0)
  const code = parseInt(str.slice(-2))
  const pos1 = parseInt(str.slice(-3,-2))
  const pos2 = parseInt(str.slice(-4,-3))
  const pos3 = parseInt(str.slice(-5,-4))
  return { code, modes:[null, pos1, pos2, pos3] }
}

function readArgs(program, op) {
  let nargs = argsNumber(op)
  let args = []
  for (let i = 1; i <= nargs; i++) {
    args.push(program.read())
  }
  return args
}

const POSITIONAL = 0
const IMMEDIATE = 1
const RELATIVE = 2

function deref(program, mode, posOrVal) {
  switch (mode) {
    case IMMEDIATE: return posOrVal // val
    case POSITIONAL: return program.get(posOrVal) // pos => val
    case RELATIVE: return program.getRel(posOrVal) // pos => val
    default:
      exit(2)
  }
}

function offset(program, mode, pos) {
  switch (mode) {
    case POSITIONAL: return pos
    case RELATIVE: return program.rel(pos)
    default:
      exit(3)
  }
}


// HALT
createCommand(99, function(program, op) {
  exit(0)
})

// ADD
createCommand(1, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  outpos = offset(program, op.modes[3], outpos)
  program.set(outpos, arg1 + arg2)
})

// MULT
createCommand(2, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  outpos = offset(program, op.modes[3], outpos)
  program.set(outpos, arg1 * arg2)
})

// INPUT
createCommand(3, function(program, op, pos) {
  pos = offset(program, op.modes[1], pos)
  program.set(pos, program.input())
})

// OUTPUT
createCommand(4, function(program, op, pos1) {
  const val = deref(program, op.modes[1], pos1)
  program.output(val)
})

// JUMP_IF
createCommand(5, function(program, op, pos1, pos2) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  if (arg1 !== 0) {
    program.moveTo(arg2)
  }
})

// JUMP_IFNOT
createCommand(6, function(program, op, pos1, pos2) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  if (arg1 === 0) {
    program.moveTo(arg2)
  }
})

// LESS_THAN
createCommand(7, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  outpos = offset(program, op.modes[3], outpos)
  program.set(outpos, arg1 < arg2 ? 1 : 0)
})

// EQUALS
createCommand(8, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  outpos = offset(program, op.modes[3], outpos)
  program.set(outpos, arg1 === arg2 ? 1 : 0)
})

// MOVREL
createCommand(9, function(program, op, pos1) {
  const arg1 = deref(program, op.modes[1], pos1)
  program.offsetRelative(arg1)
})

