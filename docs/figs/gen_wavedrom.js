const fs = require('fs');
const path = require('path');
const w = require('D:/dsh_workspace/_tools/asciidoctor-js/node_modules/wavedrom');

const OUT = __dirname;

function reg(name, fields) {
  const tree = w.renderAny(0, {reg: fields, config: {bits: 16}});
  const svg = w.onml.stringify(tree);
  fs.writeFileSync(path.join(OUT, name), svg);
}

reg('enc-alu.svg', [
  {bits: 4, name: 'f4'},
  {bits: 2, name: 'funct2'},
  {bits: 4, name: 'rd'},
  {bits: 4, name: 'rs2'},
  {bits: 2, name: '11'}
]);

reg('enc-bne.svg', [
  {bits: 4, name: 'f4'},
  {bits: 3, name: "rs1'"},
  {bits: 3, name: "rs2'"},
  {bits: 4, name: 'off4'},
  {bits: 2, name: '11'}
]);

reg('enc-blez.svg', [
  {bits: 4, name: 'f4'},
  {bits: 3, name: "rs'"},
  {bits: 7, name: 'off7'},
  {bits: 2, name: '11'}
]);

reg('enc-gppc.svg', [
  {bits: 4, name: 'f4'},
  {bits: 2, name: 'funct2'},
  {bits: 3, name: "rd'"},
  {bits: 5, name: 'off5'},
  {bits: 2, name: '11'}
]);

reg('enc-ldst.svg', [
  {bits: 4, name: 'f4'},
  {bits: 2, name: 'funct2'},
  {bits: 4, name: 'reg'},
  {bits: 2, name: 'base'},
  {bits: 2, name: 'off2'},
  {bits: 2, name: '11'}
]);

reg('enc-m.svg', [
  {bits: 4, name: 'f4'},
  {bits: 3, name: 'funct3'},
  {bits: 3, name: "rd'"},
  {bits: 3, name: "rs2'"},
  {bits: 1, name: 'spare'},
  {bits: 2, name: '11'}
]);

reg('enc-fp.svg', [
  {bits: 4, name: 'f4'},
  {bits: 2, name: 'funct2'},
  {bits: 4, name: 'fd/fs1'},
  {bits: 4, name: 'fs2'},
  {bits: 2, name: '11'}
]);

reg('enc-csr.svg', [
  {bits: 4, name: 'f4'},
  {bits: 4, name: 'csr4'},
  {bits: 4, name: 'reg4'},
  {bits: 2, name: 'op2'},
  {bits: 2, name: '11'}
]);

reg('enc-sys.svg', [
  {bits: 4, name: 'f4'},
  {bits: 10, name: 'imm10'},
  {bits: 2, name: '11'}
]);

console.log('wavedrom svgs written');
