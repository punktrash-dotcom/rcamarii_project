# Sugarcane Profit Computation

Prepared for review and advice.

## Purpose

This sheet computes the estimated profit for one sugarcane truckload.

In the current app flow, the deducted cost is focused on trucking expenses:

- Trucking Allowance
- Trucking Rental Cost, if the truck is rental

## Required Data

### Delivery Information

- Farm / Association: ______________________________
- Delivery / Batch: ______________________________
- Date: ______________________________

### Production Data

- Net Weight of Cane, in tons: ______________________________
- LKG/TC: ______________________________
- Planter Share, in %: ______________________________

### Revenue Data

- Sugar Price per LKG: ______________________________
- Molasses Quantity, in kg: ______________________________
- Molasses Price per kg: ______________________________

### Trucking Expense Data

- Trucking Allowance: ______________________________
- Trucking Type: `Owned` / `Rental`
- If `Rental`, Trucking Rental Cost: ______________________________

## Computation Structure

### 1. Convert Planter Share to Decimal

Planter Share Decimal = Planter Share / 100

Example:

- If Planter Share = 70%
- Planter Share Decimal = 0.70

### 2. Compute Sugar Proceeds

Sugar Proceeds = Net Weight of Cane x LKG/TC x Planter Share Decimal x Sugar Price per LKG

### 3. Compute Molasses Proceeds

Molasses Proceeds = Molasses Quantity x Molasses Price per kg

### 4. Compute Total Revenue

Total Revenue = Sugar Proceeds + Molasses Proceeds

### 5. Compute Trucking Expenses

Trucking Expenses = Trucking Allowance + Trucking Rental Cost

If the truck is `Owned`, then:

- Trucking Rental Cost = 0
- Trucking Expenses = Trucking Allowance only

If the truck is `Rental`, then:

- Trucking Expenses = Trucking Allowance + Trucking Rental Cost

### 6. Compute Net Profit per Truckload

Net Profit per Truckload = Total Revenue - Trucking Expenses

## ABSFI Farmer Share Reference

For ABSFI members, the sharing basis is:

- Planters = 66%
- Mills = 34%

ABSFI then takes 1% from the planter share.

### ABSFI Computation

- Planter Share = 66.00%
- ABSFI Deduction = 1% of 66.00%
- ABSFI Deduction = 0.66%
- Net Planter Share = 66.00% - 0.66%
- Net Planter Share = 65.34%

If the association is `ABSFI`, the planter share used in the calculator should be:

- 65.34%

## Fill-In Computation Sheet

### A. Production

- Net Weight of Cane = ______________________________ tons
- LKG/TC = ______________________________
- Planter Share = ______________________________ %
- Planter Share Decimal = ______________________________

### B. Revenue

- Sugar Price per LKG = ______________________________
- Sugar Proceeds = ______________________________

- Molasses Quantity = ______________________________ kg
- Molasses Price per kg = ______________________________
- Molasses Proceeds = ______________________________

- Total Revenue = ______________________________

### C. Trucking Expenses

- Trucking Allowance = ______________________________
- Trucking Type = `Owned` / `Rental`
- Trucking Rental Cost = ______________________________
- Trucking Expenses = ______________________________

### D. Result

- Net Profit per Truckload = ______________________________

## Formula Summary

```text
Planter Share Decimal = Planter Share / 100

Sugar Proceeds =
  Net Weight of Cane
  x LKG/TC
  x Planter Share Decimal
  x Sugar Price per LKG

Molasses Proceeds =
  Molasses Quantity
  x Molasses Price per kg

Total Revenue =
  Sugar Proceeds
  + Molasses Proceeds

Trucking Expenses =
  Trucking Allowance
  + Trucking Rental Cost

Net Profit per Truckload =
  Total Revenue
  - Trucking Expenses
```

## Important Note for Review

This sheet gives a per-truckload estimate based on the current harvest board pending payment flow.

If a reviewer wants a fuller farm-profit analysis, they may also want to consider:

- cutting labor
- loading labor
- fertilizer and chemicals
- land preparation
- irrigation
- association or milling deductions
- other harvest-related expenses

## Notes / Advice Requested

____________________________________________________________

____________________________________________________________

____________________________________________________________

____________________________________________________________
