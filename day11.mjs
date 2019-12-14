import { run, runSteps, compile, makeInputBuffer } from './intcomp'

const puzzle = `3,8,1005,8,321,1106,0,11,0,0,0,104,1,104,0,3,8,102,-1,8,10,1001,10,1,10,4,10,1008,8,1,10,4,10,1002,8,1,29,3,8,1002,8,-1,10,101,1,10,10,4,10,108,0,8,10,4,10,1002,8,1,50,3,8,102,-1,8,10,1001,10,1,10,4,10,1008,8,0,10,4,10,1001,8,0,73,1,1105,16,10,2,1004,8,10,3,8,1002,8,-1,10,1001,10,1,10,4,10,1008,8,0,10,4,10,1002,8,1,103,1006,0,18,1,105,14,10,3,8,102,-1,8,10,101,1,10,10,4,10,108,0,8,10,4,10,102,1,8,131,1006,0,85,1,1008,0,10,1006,0,55,2,104,4,10,3,8,102,-1,8,10,1001,10,1,10,4,10,1008,8,1,10,4,10,1001,8,0,168,2,1101,1,10,1006,0,14,3,8,102,-1,8,10,101,1,10,10,4,10,108,1,8,10,4,10,102,1,8,196,1006,0,87,1006,0,9,1,102,20,10,3,8,1002,8,-1,10,101,1,10,10,4,10,108,1,8,10,4,10,1001,8,0,228,3,8,1002,8,-1,10,101,1,10,10,4,10,108,0,8,10,4,10,1002,8,1,250,2,5,0,10,2,1009,9,10,2,107,17,10,1006,0,42,3,8,102,-1,8,10,101,1,10,10,4,10,108,1,8,10,4,10,1001,8,0,287,2,102,8,10,1006,0,73,1006,0,88,1006,0,21,101,1,9,9,1007,9,925,10,1005,10,15,99,109,643,104,0,104,1,21102,1,387353256856,1,21101,0,338,0,1105,1,442,21101,936332866452,0,1,21101,349,0,0,1105,1,442,3,10,104,0,104,1,3,10,104,0,104,0,3,10,104,0,104,1,3,10,104,0,104,1,3,10,104,0,104,0,3,10,104,0,104,1,21101,0,179357024347,1,21101,0,396,0,1105,1,442,21102,1,29166144659,1,21102,407,1,0,1105,1,442,3,10,104,0,104,0,3,10,104,0,104,0,21102,1,718170641252,1,21102,430,1,0,1106,0,442,21101,825012151040,0,1,21102,441,1,0,1106,0,442,99,109,2,21202,-1,1,1,21102,1,40,2,21102,1,473,3,21102,463,1,0,1105,1,506,109,-2,2106,0,0,0,1,0,0,1,109,2,3,10,204,-1,1001,468,469,484,4,0,1001,468,1,468,108,4,468,10,1006,10,500,1102,1,0,468,109,-2,2105,1,0,0,109,4,1202,-1,1,505,1207,-3,0,10,1006,10,523,21101,0,0,-3,22101,0,-3,1,21202,-2,1,2,21102,1,1,3,21102,1,542,0,1105,1,547,109,-4,2106,0,0,109,5,1207,-3,1,10,1006,10,570,2207,-4,-2,10,1006,10,570,22102,1,-4,-4,1105,1,638,22102,1,-4,1,21201,-3,-1,2,21202,-2,2,3,21101,0,589,0,1106,0,547,22102,1,1,-4,21101,1,0,-1,2207,-4,-2,10,1006,10,608,21102,0,1,-1,22202,-2,-1,-2,2107,0,-3,10,1006,10,630,21202,-1,1,1,21102,630,1,0,105,1,505,21202,-2,-1,-2,22201,-4,-2,-4,109,-5,2106,0,0`


const BLACK = 0
const WHITE = 1
const TURN_LEFT = 0
const TURN_RIGHT = 1
const UP = 'UP'
const LEFT = 'LEFT'
const DOWN = 'DOWN'
const RIGHT = 'RIGHT'
const CLOCKWISE = [UP, RIGHT, DOWN, LEFT]

class XY {
  constructor(x, y) {
    this.x = x
    this.y = y
  }

  toString() {
    return `${this.x}_${this.y}`
  }

  

  move(direction) {
    switch (direction) {
      case LEFT: return new XY(this.x - 1, this.y)
      case RIGHT: return new XY(this.x + 1, this.y)
      case UP: return new XY(this.x, this.y - 1)
      case DOWN: return new XY(this.x, this.y + 1)
      default: 
        throw `bad direction ${direction}`
    }
  }
}

XY.fromString = function fromString(str) {
  const splitted = str.split('_')
  const [x, y] = splitted.map(n => parseInt(n))
  return new XY(x, y)
}


let currentCoords = new XY(0, 0)
let grid = {}

let facingDirection = UP
let outputSwitch = true
let paintCount = 0

function getColor(xy) {
  let color = grid[xy]
  if (color === void 0) color = BLACK
  return color
}

function setColor(xy, color) {
  grid[xy] = color
}

setColor(currentCoords, WHITE)

const program = compile(puzzle)
  .setInput(() => {
    return getColor(currentCoords)
  })
  .setOutput(v => {
    // outputSwitch == true => output is a color to paint
    // outputSwitch == false => output is a direction to turn
    if (outputSwitch) {
      const color = v
      if (grid[currentCoords] === void 0) {
        paintCount++
      }
      setColor(currentCoords, color)
      console.log(`${currentCoords} paint it ${color ? 'white' : 'black'}`)
    } else {
      console.log(`-------------`)
      console.log(`facing`, facingDirection)
      const direction = v
      let index = CLOCKWISE.indexOf(facingDirection)
      switch (direction) {
        case TURN_LEFT: 
          console.log('TURN_LEFT')
          index--
          break
        case TURN_RIGHT: 
          console.log('TURN_RIGHT')
          index++
          break
        default: throw 'bad direction'
      }
      while (index < 0) index += CLOCKWISE.length
      while (index > (CLOCKWISE.length - 1)) index -= CLOCKWISE.length
      facingDirection = CLOCKWISE[index]
      console.log(`facing`, facingDirection)
      console.log(`currentCoords`, currentCoords)
      console.log(`move`, facingDirection)
      currentCoords = currentCoords.move(facingDirection)
      console.log(`currentCoords`, currentCoords)
      // printGrid()
    }
    outputSwitch = !outputSwitch
  })

function printGrid() {
  const xys = Object.keys(grid).map(XY.fromString)
  const maxX = Math.max.call(Math, ...(xys.map(c => c.x)))
  const minX = Math.min.call(Math, ...(xys.map(c => c.x)))
  const maxY = Math.max.call(Math, ...(xys.map(c => c.y)))
  const minY = Math.min.call(Math, ...(xys.map(c => c.y)))
  console.log('-----------')
  for (let y = minY; y <= maxY; y++) {
    for (let x = minX; x <= maxX; x++) {
      const color = getColor(new XY(x, y))
      const v = color ? "#" : " "
      process.stdout.write(v);
    }
    
    process.stdout.write("\n");
  }
  console.log('-----------')
}

run(program)
// console.log(`grid`, grid)
console.log(`Object.keys(grid)`, Object.keys(grid))
console.log(`Object.keys(grid).length`, Object.keys(grid).length)
printGrid()
console.log(`paintCount`, paintCount)