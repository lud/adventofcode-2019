

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
  return runProgram(program)
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
  // console.log(`initial`, initial)
  const memory = initial.slice()
  let cursor = 0
  let inputFun, outputFun
  const state = { 
    moveTo: n => { cursor = n },
    pos: () => cursor,
    read: () => memory[cursor++],
    get: n => {
      if (typeof memory[n] === 'undefined') {
        throw new Error(`Failed to read position ${n}`)
      }
      return memory[n]
    },
    set: (n, v) => {
      memory[n] = v 
    }, 
    transform: fn => fn(memory),
    snapshot: () => memory.slice(),
    setInput: inp => { inputFun = inp },
    setOutput: outp => { outputFun = outp },
    withIO: (inp, outp) => {
      state.setInput(inp)
      state.setOutput(outp)
      return state
    },
    fork: () => createState(memory),
    input: () => inputFun(),
    output: val => outputFun(val)
    // output
  }

  return state 
}

function runProgram(program, input, output) {
  let cursor = 0
  try {
    while (true) {
      let opcode = program.read()
      let op = readOpcode(opcode)
      let args = readArgs(program, op)
      runCommand(program, op, args)
    }
  } catch (e) {
    if (e.exitCode) {
      console.error("Program error", e)
      return `Exit: ${e.exitCode}`
    } else {
      if (e.exitCode === 0) {
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

function deref(program, mode, posOrVal) {
  switch (mode) {
    case IMMEDIATE: return posOrVal // val
    case POSITIONAL: return program.get(posOrVal) // pos => val
    default:
      exit(2)
  }
}

const POSITIONAL = 0
const IMMEDIATE = 1

const HALT = 99
const ADD = 1
const MULT = 2
const INP = 3
const OUT = 4
const JUMP_IF = 5
const JUMP_IFNOT = 6
const LESS_THAN = 7
const EQUALS = 8

createCommand(HALT, function(program, op) {
  exit(0)
})

createCommand(ADD, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  program.set(outpos, arg1 + arg2)
})

createCommand(MULT, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  program.set(outpos, arg1 * arg2)
})

createCommand(INP, function(program, op, pos) {
  program.set(pos, program.input())
})

createCommand(OUT, function(program, op, pos1) {
  const val = deref(program, op.modes[1], pos1)
  program.output(val)
})

createCommand(JUMP_IF, function(program, op, pos1, pos2) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  if (arg1 !== 0) {
    program.moveTo(arg2)
  }
})

createCommand(JUMP_IFNOT, function(program, op, pos1, pos2) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  if (arg1 === 0) {
    program.moveTo(arg2)
  }
})

createCommand(LESS_THAN, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  program.set(outpos, arg1 < arg2 ? 1 : 0)
})

createCommand(EQUALS, function(program, op, pos1, pos2, outpos) {
  const arg1 = deref(program, op.modes[1], pos1)
  const arg2 = deref(program, op.modes[2], pos2)
  program.set(outpos, arg1 === arg2 ? 1 : 0)
})