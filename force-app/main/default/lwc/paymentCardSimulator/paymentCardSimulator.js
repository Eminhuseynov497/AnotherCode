import { LightningElement, track } from 'lwc';

export default class PaymentCardSimulator extends LightningElement {
    @track isCreditCard = true;
    @track isPayPal = false;
    @track isApplePay = false;
    @track isGooglePay = false;
    @track isFlipped = false;
    @track cardNumber = '';
    @track expiryDate = '';
    @track cvv = '';
    @track showToast = false;
    @track toastMessage = '';
    @track payPalLoggedIn = false;
    @track payPalEmail = '';
    @track payPalPassword = '';
    @track payPalLoginError = '';
    @track applePayBiometry = false;
    @track applePaySuccess = false;
    @track showGooglePayCards = false;
    @track selectedGooglePayCard = '•••• 1234';

    get creditCardClass() {
        return 'payment-method ' + (this.isCreditCard ? 'selected' : '');
    }
    get payPalClass() {
        return 'payment-method ' + (this.isPayPal ? 'selected' : '');
    }
    get applePayClass() {
        return 'payment-method ' + (this.isApplePay ? 'selected' : '');
    }
    get googlePayClass() {
        return 'payment-method ' + (this.isGooglePay ? 'selected' : '');
    }

    get cardWrapperClass() {
        return 'card-wrapper ' + (this.isFlipped ? 'flipped' : '');
    }

    handleCardNumberInput(event) {
        let raw = event.target.value.replace(/\D/g, '');
        let formatted = '';
        for (let i = 0; i < raw.length; i++) {
            if (i > 0 && i % 4 === 0) {
                formatted += ' ';
            }
            formatted += raw[i];
        }
        this.cardNumber = formatted;
        const displayEl = this.template.querySelector('#displayCardNumber');
        if (displayEl) displayEl.textContent = formatted || '•••• •••• •••• ••••';
    }

    handleExpiryInput(event) {
        let raw = event.target.value.replace(/\D/g, '');
        if (raw.length > 2) {
            raw = raw.slice(0, 2) + '/' + raw.slice(2);
        }
        this.expiryDate = raw;
        const displayEl = this.template.querySelector('#displayExpiry');
        if (displayEl) displayEl.textContent = raw || 'MM/YY';
    }

    handleCvvInput(event) {
        let raw = event.target.value.replace(/\D/g, '');
        if (raw.length > 3) {
            raw = raw.slice(0, 3);
        }
        this.cvv = raw;
        const displayEl = this.template.querySelector('#displayCVV');
        if (displayEl) displayEl.textContent = raw || '•••';
    }

    handleCvvFocus() {
        this.isFlipped = true;
    }

    handleCvvBlur() {
        this.isFlipped = false;
    }

    handlePayPalEmail(event) {
        this.payPalEmail = event.target.value;
    }

    handlePayPalPassword(event) {
        this.payPalPassword = event.target.value;
    }

    handlePayPalLogin() {
        if (!this.payPalEmail || !this.payPalPassword) {
            this.payPalLoginError = 'Please enter both email and password.';
            return;
        }
        if (this.payPalEmail.includes('@') && this.payPalPassword.length >= 3) {
            this.payPalLoggedIn = true;
            this.payPalLoginError = '';
        } else {
            this.payPalLoginError = 'Invalid email or password.';
        }
    }

    handleApplePay() {
        this.applePayBiometry = true;
        setTimeout(() => {
            this.applePaySuccess = true;
            this.toastMessage = 'Apple Pay: Authenticated with Face ID. Payment successful!';
            this.showToast = true;
            setTimeout(() => {
                this.showToast = false;
            }, 5000);
        }, 1500);
    }

    handleGooglePay() {
        this.showGooglePayCards = true;
    }

    selectGooglePayCard(event) {
        this.selectedGooglePayCard = event.target.value;
    }

    selectCreditCard() {
        this.isCreditCard = true;
        this.isPayPal = false;
        this.isApplePay = false;
        this.isGooglePay = false;
        this.payPalLoggedIn = false;
        this.payPalLoginError = '';
        this.applePayBiometry = false;
        this.applePaySuccess = false;
        this.showGooglePayCards = false;
    }

    selectPayPal() {
        this.isCreditCard = false;
        this.isPayPal = true;
        this.isApplePay = false;
        this.isGooglePay = false;
        this.applePayBiometry = false;
        this.applePaySuccess = false;
        this.showGooglePayCards = false;
    }

    selectApplePay() {
        this.isCreditCard = false;
        this.isPayPal = false;
        this.isApplePay = true;
        this.isGooglePay = false;
        this.payPalLoggedIn = false;
        this.payPalLoginError = '';
        this.showGooglePayCards = false;
    }

    selectGooglePay() {
        this.isCreditCard = false;
        this.isPayPal = false;
        this.isApplePay = false;
        this.isGooglePay = true;
        this.payPalLoggedIn = false;
        this.payPalLoginError = '';
        this.applePayBiometry = false;
        this.applePaySuccess = false;
    }

    handlePay() {
        let method = '';
        if (this.isCreditCard) {
            const cleanNumber = this.cardNumber.replace(/\s/g, '');
            if (cleanNumber.length < 10) {
                alert('Please enter a valid card number.');
                return;
            }
            if (this.cvv.length < 3) {
                alert('Please enter a valid 3-digit CVV.');
                return;
            }
            method = 'Credit Card ending in ' + cleanNumber.slice(-4);
        } else if (this.isPayPal) {
            if (!this.payPalLoggedIn) {
                alert('Please log in to PayPal first.');
                return;
            }
            method = 'PayPal';
        } else if (this.isApplePay) {
            if (!this.applePaySuccess) {
                alert('Please authenticate with Face ID / Touch ID first.');
                return;
            }
            method = 'Apple Pay';
        } else if (this.isGooglePay) {
            method = 'Google Pay (' + this.selectedGooglePayCard + ')';
        }

        this.toastMessage = `Payment via ${method} has been processed successfully!`;
        this.showToast = true;
        setTimeout(() => {
            this.showToast = false;
        }, 5000);
    }
}