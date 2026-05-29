import { LightningElement } from 'lwc';

export default class NewPropertyButton extends LightningElement {
    showFlow = false;

    invoke() {
        this.showFlow = true;
    }

    openFlow() {
        this.showFlow = true;
    }

    handleFlowFinish(event) {
        const status = event.detail?.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
    }

    closeFlow() {
        this.showFlow = false;
    }
}