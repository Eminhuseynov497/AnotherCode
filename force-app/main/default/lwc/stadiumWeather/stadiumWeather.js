import { LightningElement, api, wire } from 'lwc';
import getWeather from '@salesforce/apex/WeatherController.getWeather';

export default class StadiumWeatherNew extends LightningElement {
    @api recordId;
    @api stadiumName;
    @api coldImageUrl = '/resource/coldImage';
    @api coolImageUrl = '/resource/coolImage';
    @api warmImageUrl = '/resource/warmImag';
    @api hotImageUrl = '/resource/hotimage';
    @api veryHotImageUrl = '/resource/veryhotimage';

    weather;
    error;

    connectedCallback() {
        this.updateHostClass();
    }

    @wire(getWeather, { 
        stadiumId: '$recordId', 
        stadiumName: '$stadiumName' 
    })
    wiredWeather({ data, error }) {
        if (data) {
            this.weather = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.weather = null;
        } else {
            this.weather = this.getDemoWeather();
            this.error = undefined;
        }
        this.updateHostClass();
    }

    get currentImageUrl() {
        if (!this.weather || !this.weather.temp) {
            return this.warmImageUrl;
        }
        const temp = Number(this.weather.temp);
        if (temp < 10) {
            return this.coldImageUrl;
        } else if (temp >= 10 && temp < 18) {
            return this.coolImageUrl;
        } else if (temp >= 18 && temp < 25) {
            return this.warmImageUrl;
        } else if (temp >= 25 && temp < 30) {
            return this.hotImageUrl;
        } else {
            return this.veryHotImageUrl;
        }
    }

    get temperatureClass() {
        if (!this.weather || !this.weather.temp) return 'temp-warm';
        const temp = Number(this.weather.temp);
        if (temp < 10) return 'temp-cold';
        if (temp < 18) return 'temp-cool';
        if (temp < 25) return 'temp-warm';
        if (temp < 30) return 'temp-hot';
        return 'temp-veryhot';
    }

    updateHostClass() {
        this.classList.remove('temp-cold', 'temp-cool', 'temp-warm', 'temp-hot', 'temp-veryhot');
        // Добавляем актуальный
        const cls = this.temperatureClass;
        if (cls) {
            this.classList.add(cls);
        }
    }

    getDemoWeather() {
        const conditions = ['Sunny', 'Clear Sky', 'Partly Cloudy', 'Light Breeze'];
        const randomIndex = Math.floor(Math.random() * conditions.length);
        const temp = (20 + Math.random() * 10).toFixed(1);
        const feelsLike = (temp - 2 + Math.random() * 4).toFixed(1);
        return {
            temp: temp,
            feelsLike: feelsLike,
            description: conditions[randomIndex].toLowerCase(),
            location: this.stadiumName || 'Stadium'
        };
    }

    get errorMessage() {
        if (!this.error) return '';
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        return String(this.error);
    }
}