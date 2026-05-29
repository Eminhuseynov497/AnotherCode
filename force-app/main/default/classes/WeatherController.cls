public with sharing class WeatherController {
    private static final String API_KEY = 'your_api_key_here';
    private static final String BASE_URL = 'https://api.openweathermap.org/data/2.5/weather';
    
    @AuraEnabled(cacheable=true)
    public static WeatherInfo getWeather(Id stadiumId, String stadiumName) {
        String city = null;
        String country = null;
        String displayLocation = '';
        
        if (stadiumId != null) {
            List<Stadium__c> stadiums = [SELECT City__c, Country__c FROM Stadium__c WHERE Id = :stadiumId LIMIT 1];
            if (!stadiums.isEmpty()) {
                city = stadiums[0].City__c;
                country = stadiums[0].Country__c;
                displayLocation = city + (String.isNotBlank(country) ? ', ' + country : '');
            }
        }
        
        if (String.isBlank(city) && String.isNotBlank(stadiumName)) {
            List<Stadium__c> stadiums = [SELECT City__c, Country__c FROM Stadium__c WHERE Name = :stadiumName LIMIT 1];
            if (!stadiums.isEmpty()) {
                city = stadiums[0].City__c;
                country = stadiums[0].Country__c;
                displayLocation = city + (String.isNotBlank(country) ? ', ' + country : '');
            } else {
                city = stadiumName;
                country = '';
                displayLocation = stadiumName;
            }
        }
        
        if (String.isBlank(city)) {
            city = 'Barcelona';
            country = 'ES';
            displayLocation = 'Barcelona, ES';
        }
        
        if (String.isNotBlank(API_KEY) && API_KEY != 'ваш_ключ_здесь') {
            try {
                String url = BASE_URL + '?q=' + EncodingUtil.urlEncode(city, 'UTF-8');
                if (String.isNotBlank(country)) {
                    url += ',' + EncodingUtil.urlEncode(country, 'UTF-8');
                }
                url += '&appid=' + API_KEY + '&units=metric&lang=en';
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(url);
                req.setMethod('GET');
                req.setTimeout(60000);
                
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                if (res.getStatusCode() == 200) {
                    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    Map<String, Object> main = (Map<String, Object>) result.get('main');
                    List<Object> weatherArr = (List<Object>) result.get('weather');
                    Map<String, Object> weatherData = (Map<String, Object>) weatherArr[0];
                    String iconCode = (String) weatherData.get('icon');
                    
                    return new WeatherInfo(
                        (Decimal) main.get('temp'),
                        (Decimal) main.get('feels_like'),
                        (String) weatherData.get('description'),
                        'https://openweathermap.org/img/wn/' + iconCode + '.svg',
                        displayLocation
                    );
                }
            } catch (Exception e) {
                System.debug('Weather Error: ' + e.getMessage());
            }
        }
        
        return getDemoWeather(displayLocation);
    }
    
    private static WeatherInfo getDemoWeather(String location) {
        String[] conditions = new String[]{'Sunny', 'Clear Sky', 'Partly Cloudy', 'Light Breeze'};
        String[] icons = new String[]{'01d', '01d', '02d', '03d'};
        Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), conditions.size());
        
        Decimal temp = 22.0 + (Math.random() * 6 - 3);
        Decimal feelsLike = temp + (Math.random() * 2 - 1);
        
        return new WeatherInfo(
            temp,
            feelsLike,
            conditions[idx].toLowerCase(),
            'https://openweathermap.org/img/wn/' + icons[idx] + '.svg',
            location
        );
    }
    
    public class WeatherInfo {
        @AuraEnabled public Decimal temp;
        @AuraEnabled public Decimal feelsLike;
        @AuraEnabled public String description;
        @AuraEnabled public String iconUrl;
        @AuraEnabled public String location;
        
        public WeatherInfo(Decimal temp, Decimal feelsLike, String description, String iconUrl, String location) {
            this.temp = temp;
            this.feelsLike = feelsLike;
            this.description = description;
            this.iconUrl = iconUrl;
            this.location = location;
        }
    }
}