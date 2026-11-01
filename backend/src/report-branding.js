import {fileURLToPath} from 'node:url';

const logoPath=fileURLToPath(new URL('../assets/hasani_payroll_logo.png',import.meta.url));
// Original supplied artwork is 2172x724, with white margins around the mark.
// Clip those margins in the PDF layout without modifying the source image.
const artwork={x:30,y:190,width:2115,height:340};
export function drawReportLogo(doc,x,y,{width=220,height=34}={}) {
  const scale=Math.min(width/artwork.width,height/artwork.height);
  const left=x+(width-artwork.width*scale)/2-artwork.x*scale;
  const top=y+(height-artwork.height*scale)/2-artwork.y*scale;
  doc.save().rect(x,y,width,height).clip();
  doc.image(logoPath,left,top,{width:2172*scale});
  doc.restore();
}
