import { run, runSteps, compile, makeInputBuffer } from './intcomp'

const puzzle = `3,8,1001,8,10,8,105,1,0,0,21,46,67,88,101,126,207,288,369,450,99999,3,9,1001,9,5,9,1002,9,5,9,1001,9,5,9,102,3,9,9,101,2,9,9,4,9,99,3,9,102,4,9,9,101,5,9,9,102,5,9,9,101,3,9,9,4,9,99,3,9,1001,9,3,9,102,2,9,9,1001,9,5,9,102,4,9,9,4,9,99,3,9,102,3,9,9,1001,9,4,9,4,9,99,3,9,102,3,9,9,1001,9,3,9,1002,9,2,9,101,4,9,9,102,3,9,9,4,9,99,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1002,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,101,1,9,9,4,9,99,3,9,101,1,9,9,4,9,3,9,1001,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,1,9,4,9,3,9,1002,9,2,9,4,9,99,3,9,101,1,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,102,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,2,9,4,9,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,1001,9,1,9,4,9,99,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,101,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,1,9,9,4,9,3,9,101,1,9,9,4,9,3,9,101,1,9,9,4,9,99,3,9,101,1,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,1,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,1002,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,1002,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,99`
// const puzzle = '3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5'
// const puzzle = '3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55,1005,55,26,1001,54,-5,54,1105,1,12,1,53,54,53,1008,54,0,55,1001,55,1,55,2,53,55,53,4,53,1001,56,-1,56,1005,56,6,99,0,0,0,0,10'

function createPhaseSettings(phases) {
  phases = phases.slice().sort()
  const min = Math.min.call(null, ...phases)
  const max = Math.max.call(null, ...phases)
  const result = []
  for (let a = min; a <= max; a++)
    for (let b = min; b <= max; b++)
      for (let c = min; c <= max; c++)
        for (let d = min; d <= max; d++)
          for (let e = min; e <= max; e++) {
            const candidate = [a,b,c,d,e]
            const isUnique = candidate.filter((v, i, self) => self.indexOf(v) === i).length === candidate.length
            if (isUnique) {
              result.push(candidate)
            }
          }
  return result
}

const forkable = compile(puzzle)

// const phaseSettings = createPhaseSettings([0,1,2,3,4])


// function runAmplifiers(phases) {
//   let pipedValue = 0
//   ;phases.forEach((phase, i) => {
//     console.log('--- Running program', 'ABCDE'[i])
//     const program = forkable.fork()
//       .withIO(
//         // input
//         makeInputBuffer([phase, pipedValue]),
//         // output
//         val => { pipedValue = val})
//     run(program)
//   })
//   console.log(`return `, pipedValue)
//   return pipedValue
// }

// console.log(`phaseSettings`, phaseSettings)

// let maxValue = 0
// let maxPhases

// phaseSettings.forEach(phases => {
//   console.log('run phases', phases)
//   const value = runAmplifiers(phases)
//   if (value > maxValue) {
//     maxValue = value
//     maxPhases = phases
//   }
// })

// console.log('maxValue', maxValue)
// console.log(`maxPhases`, maxPhases)

// Feedback

function runAmplifiersFeedback(phases) {
  let pipedValue = 0
  function initProgram(phase, name) {
    const program = forkable
      .fork()
      .setInput(makeInputBuffer([phase]))
    program.__name = 'Amplifier ' + name
    return program
  }
  const programs = phases.map((v, i) => initProgram(v, 'ABCDE'[i]))
  while (programs.length) {
    // at each iteration we take a program from the stack. 
    // We feed the current pipedValue to it and make it run, outputing
    // a new piped value.
    // if the program is not halted we push it on the stack
    let outputed = false
    const program = programs.shift()
    program.setOutput(val => {
      console.log('output', val)
      pipedValue = val
      outputed = true
    })
    console.log('Running program', program.__name)
    program.input.push(pipedValue)
    while(!outputed && !program.isHalted()) {
      runSteps(program, 1)
    }
    if (!program.isHalted()) {
      programs.push(program)
    } else {
      console.log("Program halted")
    }
  }
  console.log(`return `, pipedValue)
  return pipedValue
}

const feedbackSettings = createPhaseSettings([5,6,7,8,9])
console.log(`feedbackSettings`, feedbackSettings)

let maxValue = 0
let maxPhases

feedbackSettings.forEach(phases => {
  console.log('run phases', phases)
  const value = runAmplifiersFeedback(phases)
  if (value > maxValue) {
    maxValue = value
    maxPhases = phases
  }
})

console.log('maxValue', maxValue)