/* global axios */
import ApiClient from './ApiClient';

class BrazilToolsAPI extends ApiClient {
  constructor() {
    super('brazil_tools', { accountScoped: true });
  }

  generatePix(data) {
    return axios.post(`${this.url}/pix`, data);
  }

  lookupCep(cep) {
    const cleanCep = String(cep || '').replace(/\D/g, '');
    return axios.get(`${this.url}/cep/${cleanCep}`);
  }

  validateDocument(document) {
    return axios.post(`${this.url}/validate_document`, { document });
  }

  getWhatsappStatus({ inboxId, includeQr = false }) {
    return axios.get(`${this.url}/whatsapp_status`, {
      params: { inbox_id: inboxId, include_qr: includeQr },
    });
  }
}

export default new BrazilToolsAPI();
