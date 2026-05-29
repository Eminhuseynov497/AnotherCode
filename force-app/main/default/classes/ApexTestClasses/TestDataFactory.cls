@isTest
public class TestDataFactory {

    public static Sport__c createSport(String name) {
        Sport__c sport = new Sport__c(Name = name, Is_Active__c = true);
        insert sport;
        return sport;
    }
    
    public static League__c createLeague(String name, String country, String season, Id sportId) {
        League__c league = new League__c(
            Name = name,
            Country__c = country,
            Season__c = season,
            Is_Active__c = true,
            Sport__c = sportId
        );
        insert league;
        return league;
    }
    
    public static Stadium__c createStadium(String name) {
        Stadium__c stadium = new Stadium__c(
            Name = name,
            City__c = 'Test City',
            Country__c = 'Test Country',
            Year_Built__c = 2000,
            Has_Roof__c = true,
            Parking_Capacity__c = 1000
        );
        insert stadium;
        return stadium;
    }
    
    public static Stadium_Section__c createSection(Id stadiumId, String name, Integer rowCount, Integer seatsPerRow, Decimal basePrice, String category) {
        Stadium_Section__c section = new Stadium_Section__c(
            Name = name,
            Stadium__c = stadiumId,
            Category__c = category,
            Row_Count__c = rowCount,
            Seats_Per_Row__c = seatsPerRow,
            Base_Price__c = basePrice,
            Is_Active__c = true,
            Sort_Order__c = 1,
            Color_Code__c = '#000000'
        );
        insert section;
        return section;
    }
    
    public static Team__c createTeam(String name, Id leagueId, Id stadiumId) {
        Team__c team = new Team__c(
            Name = name,
            League__c = leagueId,
            Home_Stadium__c = stadiumId,
            Is_Active__c = true
        );
        insert team;
        return team;
    }
    
    public static Sport_Event__c createEvent(Id stadiumId, Id homeTeamId, Id awayTeamId, Id leagueId, 
                                              String season, DateTime eventDateTime, String eventType, 
                                              Decimal priceMultiplier, String status) {
        Sport_Event__c ev = new Sport_Event__c(
            Stadium__c = stadiumId,
            Home_Team__c = homeTeamId,
            Away_Team__c = awayTeamId,
            League__c = leagueId,
            Season__c = season,
            Date_Time__c = eventDateTime,
            Gate_Open_Time__c = eventDateTime.addHours(-1),
            Event_Type__c = eventType,
            Price_Multiplier__c = priceMultiplier,
            Status__c = status
        );
        insert ev;
        return ev;
    }
    
    public static Ticket__c createTicket(Id eventId, Id sectionId, Integer rowNumber, Integer seatNumber, 
                                         String status, Decimal basePrice) {
        Ticket__c ticket = new Ticket__c(
            Sport_Event__c = eventId,
            Stadium_Section__c = sectionId,
            Row_Number__c = rowNumber,
            Seat_Number__c = seatNumber,
            Status__c = status,
            Base_Price__c = basePrice,
            Dynamic_Price__c = basePrice,
            Seat_Key__c = eventId + '-' + sectionId + '-' + rowNumber + '-' + seatNumber
        );
        insert ticket;
        return ticket;
    }
    
    public static List<Ticket__c> generateTicketsForEvent(Id eventId, Id sectionId, Integer rowCount, Integer seatsPerRow, Decimal basePrice) {
        List<Ticket__c> tickets = new List<Ticket__c>();
        for (Integer r = 1; r <= rowCount; r++) {
            for (Integer s = 1; s <= seatsPerRow; s++) {
                Ticket__c t = new Ticket__c(
                    Sport_Event__c = eventId,
                    Stadium_Section__c = sectionId,
                    Row_Number__c = r,
                    Seat_Number__c = s,
                    Status__c = 'Available',
                    Base_Price__c = basePrice,
                    Dynamic_Price__c = basePrice,
                    Seat_Key__c = eventId + '-' + sectionId + '-' + r + '-' + s
                );
                tickets.add(t);
            }
        }
        insert tickets;
        return tickets;
    }
    
    public static Fan__c createFan(String email, String firstName, String lastName, String loyaltyTier, 
                                   Integer loyaltyPoints, Integer lifetimePoints) {
        Fan__c fan = new Fan__c(
            First_Name__c = firstName,
            Last_Name__c = lastName,
            Email__c = email,
            Phone__c = '1234567890',
            Date_of_Birth__c = Date.newInstance(1990, 1, 1),
            City__c = 'Test City',
            Registration_Date__c = Date.today(),
            Loyalty_Tier__c = loyaltyTier,
            Loyalty_Points_Balance__c = loyaltyPoints,
            Lifetime_Points__c = lifetimePoints
        );
        insert fan;
        return fan;
    }

    public static Purchase_Order__c createOrder(Id fanId, Id eventId, String status, 
                                                 Decimal subtotal, Decimal discount, Integer pointsUsed) {
        Purchase_Order__c order = new Purchase_Order__c(
            Fan__c = fanId,
            Sport_Event__c = eventId,
            Status__c = status,
            Order_Date__c = Date.today(),
            Subtotal__c = subtotal,
            Discount_Amount__c = discount,
            Loyalty_Points_Used__c = pointsUsed,
            Payment_Method__c = 'Card',
            Promo_Code_Applied__c = null
        );
        insert order;
        return order;
    }

    public static Season_Pass__c createSeasonPass(Id fanId, Id teamId, Id sectionId, String season, 
                                                   Date startDate, Date endDate, String status, 
                                                   Decimal price, String paymentPlan) {
        Season_Pass__c pass = new Season_Pass__c(
            Fan__c = fanId,
            Team__c = teamId,
            Stadium_Section__c = sectionId,
            Season__c = season,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Status__c = status,
            Season_Pass_Price__c = price,
            Payment_Plan__c = paymentPlan,
            Auto_Renew__c = true
        );
        insert pass;
        return pass;
    }

    public static Loyalty_Transaction__c createLoyaltyTransaction(Id fanId, Id orderId, String type, 
                                                                   Integer points, String reason) {
        Loyalty_Transaction__c trans = new Loyalty_Transaction__c(
            Fan__c = fanId,
            Purchase_Order__c = orderId,
            Type__c = type,
            Points__c = points,
            Reason__c = reason,
            Transaction_Date__c = Date.today()
        );
        insert trans;
        return trans;
    }
}