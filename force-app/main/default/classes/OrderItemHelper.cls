public with sharing class OrderItemHelper {
    public OrderItemHelper() {

    }


    public static void checkError(List<OrderItem> orderItemList){
        for (OrderItem orderItem : orderItemList){
            if(orderItem.Quantity <= 0){
                orderItem.addError(Label.OrderItemQuantityError);
            } else if (orderItem.UnitPrice <= 0){
                orderItem.addError(Label.OrderItemPriceError);
            }
        }
    }


    public static List<OrderItem> calcPrice (List<OrderItem> orderItemList){
        Set<Id> orderIdSet = new Set<Id>();
        Set<Id> productIdSet = new Set<Id>();

        for (OrderItem orderItem : orderItemList){
            orderIdSet.add(orderItem.OrderId);
            productIdSet.add(orderItem.product2Id);
        }

        Map<Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, AccountId, Account.AccountGroup__c, DistributionCenter__c, DistributionCenter__r.State__c
            FROM Order
            WHERE Id IN: orderIdSet
        ]);

        Map<Id, Product2> ProductMap = new Map<Id, Product2>([
            SELECT Id, ProductHierarchy__c
            FROM Product2
            WHERE Id IN: productIdSet
        ]);

        Map<OrderItem, PriceMargin__c> orderItemToMargin = searchMargin(orderItemList, orderMap, ProductMap);

        for(OrderItem orderItem : orderItemToMargin.keySet()){
            PriceMargin__c priceMargin = orderItemToMargin.get(orderItem);

            if(priceMargin != null){
                orderItem.PriceMargin__c = priceMargin.Id;
                orderItem.Price__c = orderItem.ListPrice - (orderItem.ListPrice * (priceMargin.Margin__c/100));
            }
        }
        return new List<OrderItem> (orderItemToMargin.keySet());

    }

    public static Map<OrderItem, PriceMargin__c> searchMargin(List<OrderItem> orderItemList,  Map<Id, Order> orderMap,  Map<Id, Product2> ProductMap){
        Set<Id> productIds = new Set<Id>();
        Set<Id> hierarchyIds = new Set<Id>();
        Set<Id> accountsIds = new Set<Id>();
        Set<Id> groupIds = new Set<Id>();
        Set<Id> distributionIds = new Set<Id>();
        Set<Id> stateIds = new Set<Id>();

        for(Order order : orderMap.values()){
            accountsIds.add(order.AccountId);
            groupIds.add(order.Account.AccountGroup__c);
            distributionIds.add(order.DistributionCenter__c);
            stateIds.add(order.DistributionCenter__r.State__c);
        }

        for(Product2 product : ProductMap.values()){
            productIds.add(product.Id);
            productIds.add(product.ProductHierarchy__c);

        }


        List<PriceMargin__c> priceMarginList = [
            SELECT Id, Product__c, ProductHierarchy__c, Account__c, AccountGroup__c, DistributionCenter__c, State__c, Margin__c, Score__c
            FROM PriceMargin__c
            WHERE (Product__c IN: productIds OR Product__c = null) AND 
            (ProductHierarchy__c IN: hierarchyIds OR ProductHierarchy__c = null) AND
            (Account__c IN: accountsIds OR Account__c = null) AND
            (AccountGroup__c IN: groupIds OR AccountGroup__c = null) AND
            (DistributionCenter__c IN: distributionIds OR DistributionCenter__c = null) AND
            (State__c IN: stateIds OR  State__c = null) 
            ORDER BY Score__c  
        ];

        Map<OrderItem, PriceMargin__c> orderItemToMargin = new Map<OrderItem, PriceMargin__c>();

        for(OrderItem orderItem: orderItemList){
            orderItemToMargin.put(orderItem, null);

            for(PriceMargin__c margin : priceMarginList){
                if(matchMargin(margin, OrderItem, orderMap, productMap)){
                    orderItemToMargin.put(orderItem, margin);
                    break;
                }
            }
        }
        

        return orderItemToMargin;
    }


    public static Boolean matchMargin(PriceMargin__c margin, OrderItem OrderItem, Map<Id, Order> orderMap, Map<Id, Product2> productMap){
        return (String.isBlank(margin.Product__c) || margin.Product__c == orderItem.Product2Id) &&
        (String.isBlank(margin.ProductHierarchy__c) || margin.ProductHierarchy__c == productMap.get(OrderItem.Product2Id).ProductHierarchy__c) &&
        (String.isBlank(margin.Account__c) || margin.Account__c == orderMap.get(OrderItem.OrderId).AccountId) &&
        (String.isBlank(margin.AccountGroup__c) || margin.AccountGroup__c == orderMap.get(OrderItem.OrderId).Account.AccountGroup__c) &&
        (String.isBlank(margin.DistributionCenter__c) || margin.DistributionCenter__c == orderMap.get(OrderItem.OrderId).DistributionCenter__c) &&
        (String.isBlank(margin.State__c) || margin.State__c == orderMap.get(OrderItem.OrderId).DistributionCenter__r.State__c);
    }

}