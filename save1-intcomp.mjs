

export function run(str, opts = {}) {
  const { input, output, transform } = opts
  let memory = str.split(',').map(n => parseInt(n))
  memory = transform ? transform(memory) : memory
  return runProgram(createState(memory, input, output))
}

const commands = []

function createCommand(code, fn) {
  commands[code] = {
    exec: fn,
    nargs: fn.length - 2 // length minus program and com
  }
}

function getCommand(com) {
  const { code } = com
  if (commands[code]) {
    return commands[code]
  }
  else {
    console.error("Error reading command", com)
    throw new Error(`Unknown command ${code}`)
  }
}

function runCommand(program, com, args) {
  getCommand(com).exec(program, com, ...args)
}

function argsNumber(com) {
  return getCommand(com).nargs
}

function createState(initial, input, output) {
  // console.log(`initial`, initial)
  const memory = initial.slice()
  return { 
    get: n => memory[n],
    put: (n, v) => { memory[n] = v }, 
    mem: fn => fn(memory),
    input, 
    output,
    snapshot: () => memory.slice()
  }
}

function runProgram(program, input, output) {
  let cursor = 0
  try {
    while (true) {
      // console.log('------------------')
      // console.log(`cursor`, cursor)
      let opcode = program.get(cursor)
      let com = readOpcode(opcode)
      // console.log(`com`, com)
      cursor += 1
      // console.log(`cursor`, cursor)
      let nargs = argsNumber(com)
      // console.log(`nargs`, nargs)
      let args
      [args, cursor] = readArgs(program, cursor, nargs)
      // console.log(`args`, args)
      // console.log(`cursor`, cursor)
      runCommand(program, com, args)
      // console.log(`program`, program)
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
  console.log(`str`, str)
  const code = parseInt(str.slice(-2))
  const arg1 = parseInt(str.slice(-3,-2))
  const arg2 = parseInt(str.slice(-4,-3))
  const arg3 = parseInt(str.slice(-5,-4))
  return { code, modes:[null, arg1, arg2, arg3] }
}

function readArgs(program, cursor, nargs) {
  let args = []
  while(nargs--) {
    args.push(program.get(cursor++))
  }
  return [args, cursor]
}

const POSITIONAL = 0
const IMMEDIATE = 1

const HALT = 99
const ADD = 1
const MULT = 2
const INP = 3
const OUT = 4

createCommand(HALT, function(program, com) {
  exit(0)
})

createCommand(ADD, function(program, com, arg1, arg2, outpos) {

  // console.log(`outpos`, outpos)
  program.mem(mem => { mem[outpos] = mem[arg1] + mem[arg2] })
})

createCommand(MULT, function(program, com, arg1, arg2, outpos) {
  arg1 = com.modes[1] === IMMEDIATE ? arg1 : program.get(arg1)
  arg2 = com.modes[2] === IMMEDIATE ? arg2 : program.get(arg2)
  console.log(`arg1`, arg1)
  console.log(`arg2`, arg2)
  program.put(outpos, arg1 * arg2)
})

createCommand(INP, function(program, com, pos) {
  console.log(`program`, program)
  program.put(pos, program.input())
})

createCommand(OUT, function(program, com, pos) {
  program.output(program.get(pos))
})