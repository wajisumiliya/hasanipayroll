import {renderLateReport} from './late-report-export.js';
export const renderQrExport = data => renderLateReport({...data,view:'qr-attendance'});
