import { run, compile } from './intcomp'

const puzzle = `3,8,1001,8,10,8,105,1,0,0,21,46,67,88,101,126,207,288,369,450,99999,3,9,1001,9,5,9,1002,9,5,9,1001,9,5,9,102,3,9,9,101,2,9,9,4,9,99,3,9,102,4,9,9,101,5,9,9,102,5,9,9,101,3,9,9,4,9,99,3,9,1001,9,3,9,102,2,9,9,1001,9,5,9,102,4,9,9,4,9,99,3,9,102,3,9,9,1001,9,4,9,4,9,99,3,9,102,3,9,9,1001,9,3,9,1002,9,2,9,101,4,9,9,102,3,9,9,4,9,99,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1002,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,101,1,9,9,4,9,99,3,9,101,1,9,9,4,9,3,9,1001,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,1,9,4,9,3,9,1002,9,2,9,4,9,99,3,9,101,1,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,102,2,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,1,9,4,9,3,9,1001,9,2,9,4,9,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,1001,9,1,9,4,9,99,3,9,101,2,9,9,4,9,3,9,101,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,2,9,9,4,9,3,9,1001,9,1,9,4,9,3,9,101,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,1,9,9,4,9,3,9,101,1,9,9,4,9,3,9,101,1,9,9,4,9,99,3,9,101,1,9,9,4,9,3,9,102,2,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,101,1,9,9,4,9,3,9,1002,9,2,9,4,9,3,9,1002,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,1002,9,2,9,4,9,3,9,1001,9,2,9,4,9,3,9,102,2,9,9,4,9,99`

const phaseSettings = (function(){
  const result = []
  for (let a = 0; a < 5; a++)
    for (let b = 0; b < 5; b++)
      for (let c = 0; c < 5; c++)
        for (let d = 0; d < 5; d++)
          for (let e = 0; e < 5; e++) {
            const candidate = [a,b,c,d,e]
            const isUnique = candidate.filter((v, i, self) => self.indexOf(v) === i).length === candidate.length
            if (isUnique) {
              result.push(candidate)
            }
          }
  return result
}())

const forkable = compile(puzzle)

function makeIOPipe(pipedValue) {
  let pipedValue = 
}

function runAmplifiers(phases) {
  let pipedValue = 0
  function makeInput(initVal) {
    let calledOnce = false
    return function() {
      if (calledOnce) {
        console.log('sending pipe', pipedValue)
        return pipedValue
      }
      else {
        console.log('sending phase', initVal)
        calledOnce = true
        return initVal
      }
    }
  }
  function makeOutput() {
    return function(value) {
      console.log(`setting pipe`, value)
      pipedValue = value
    }
  }

  [0,1,2,3,4].forEach(phaseIndex => {
    console.log('--- Running program', 'ABCDE'[phaseIndex])
    const program = forkable.fork().withIO(makeInput(phases[phaseIndex]), makeOutput())   
    run(program)
  })
  console.log(`return `, pipedValue)
  return pipedValue
}

console.log(`phaseSettings`, phaseSettings)

let maxValue = 0
let maxPhases

phaseSettings.forEach(phases => {
  console.log('run phases', phases)
  const value = runAmplifiers(phases)
  if (value > maxValue) {
    maxValue = value
    maxPhases = phases
  }
})

console.log('maxValue', maxValue)
console.log(`maxPhases`, maxPhases)