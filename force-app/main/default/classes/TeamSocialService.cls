public with sharing class TeamSocialService {
    
    @AuraEnabled(cacheable=true)
    public static SocialLinksResult getSocialLinksByTeamId(Id teamId) {
        Team__c team = [SELECT Name FROM Team__c WHERE Id = :teamId LIMIT 1];
        String teamName = team.Name;
        Map<String, String> links = getSocialLinksByName(teamName);
        SocialLinksResult result = new SocialLinksResult();
        result.teamName = teamName;
        result.instagram = links.get('instagram');
        result.twitter = links.get('twitter');
        result.facebook = links.get('facebook');
        return result;
    }
    
    private static Map<String, String> getSocialLinksByName(String teamName) {
        Map<String, String> links = new Map<String, String>();
        String key = teamName.trim().toLowerCase();
        
        Map<String, Map<String, String>> mockData = new Map<String, Map<String, String>>{
            'real madrid' => new Map<String, String>{
                'instagram' => 'https://www.instagram.com/realmadrid',
                'twitter'   => 'https://twitter.com/realmadrid',
                'facebook'  => 'https://www.facebook.com/realmadrid'
            },
            'barcelona' => new Map<String, String>{
                'instagram' => 'https://www.instagram.com/fcbarcelona',
                'twitter'   => 'https://twitter.com/fcbarcelona',
                'facebook'  => 'https://www.facebook.com/fcbarcelona'
            },
            'liverpool' => new Map<String, String>{
                'instagram' => 'https://www.instagram.com/liverpoolfc',
                'twitter'   => 'https://twitter.com/liverpoolfc',
                'facebook'  => 'https://www.facebook.com/liverpoolfc'
            },
            'manchester united' => new Map<String, String>{
                'instagram' => 'https://www.instagram.com/manchesterunited',
                'twitter'   => 'https://twitter.com/manutd',
                'facebook'  => 'https://www.facebook.com/manchesterunited'
            }
        };
        
        if (mockData.containsKey(key)) {
            links = mockData.get(key);
        } else {
            links.put('instagram', null);
            links.put('twitter', null);
            links.put('facebook', null);
        }
        return links;
    }

    public class SocialLinksResult {
        @AuraEnabled public String teamName;
        @AuraEnabled public String instagram;
        @AuraEnabled public String twitter;
        @AuraEnabled public String facebook;
    }
}