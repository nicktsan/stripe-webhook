module.exports = {
    moduleNameMapper: {
        "^/opt/nodejs/(.*)": "./src/layers/utils/$1",
    },
    transform: {
        "^.+\\.(t|j)sx?$": "@swc/jest",
    },
}