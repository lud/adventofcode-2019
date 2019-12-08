import { run, compile, makeInputBuffer } from './intcomp'

function assertEquals(left, right) {
  if (left.toString() !== right.toString())
  throw new Error(`assetion failed
    left  : ${left}
    right : ${right}`)
}

assertEquals(run('1,0,0,0,99'), [ 2, 0, 0, 0, 99 ])
assertEquals(run('2,3,0,3,99'), [ 2, 3, 0, 6, 99 ])
assertEquals(run('2,4,4,5,99,0'), [ 2, 4, 4, 5, 99, 9801 ])
assertEquals(run('1,1,1,4,99,5,6,0,99'), [ 30, 1, 1, 4, 2, 5, 6, 0, 99 ])

;(function(){
  const input = () => 1234
  const output = val => assertEquals(val, 1234)
  run('3,5,4,5,99', {input, output})
}())

;(function(){
  const input = makeInputBuffer()
  const output = val => assertEquals(val, 1234)
  const program = compile('3,5,4,5,99').setInput(input)
  input.push(1234)
  console.log(`input.__buffer`, input.__buffer)
  run('3,5,4,5,99', {input, output})
}())


assertEquals(run('1002,4,3,4,33'), [ 1002,4,3,4,99 ])

function runSuite(program, suites) {
  suites.forEach(suite => {
    const { expected, values } = suite
    values.map(v => {
      run(program, {
        input: () => v, 
        output: val => {
          console.log('output', val)
          try {
            assertEquals(expected, val)
          } catch(e) {
            console.error(e)
          }
        }
      })
    })
  })
}

const isEqualTo8_position = '3,9,8,9,10,9,4,9,99,-1,8'
runSuite(isEqualTo8_position, [
  {expected: 0, values: [1,2,3,4,5,6,7,9,10,11]},
  {expected: 1, values: [8]}
])

const isEqualTo8_immediate = '3,3,1108,-1,8,3,4,3,99'
runSuite(isEqualTo8_immediate, [
  {expected: 0, values: [1,2,3,4,5,6,7,9,10,11]},
  {expected: 1, values: [8]}
])

const isLessThan8_position = '3,9,7,9,10,9,4,9,99,-1,8'
runSuite(isLessThan8_position, [
  {expected: 0, values: [8,9,10,11]},
  {expected: 1, values: [1,2,3,4,5,6,7]}
])

const isLessThan8_immediate = '3,3,1107,-1,8,3,4,3,99'
runSuite(isLessThan8_immediate, [
  {expected: 0, values: [8,9,10,11]},
  {expected: 1, values: [1,2,3,4,5,6,7]}
])


const compareTo8 = '3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99'
runSuite(compareTo8, [
  {expected: 1001, values: [9,10,11,12]},
  {expected: 1000, values: [8]},
  {expected: 999, values: [1,2,3,4,5,6,7]}
])

// Test less than 8, position mode
// runSuite({expected: 0, values: [1,2,3,4,5,6,7,9,10,11]}, '3,9,7,9,10,9,4,9,99,-1,8')


console.log(`ok`)


