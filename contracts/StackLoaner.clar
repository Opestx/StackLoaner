;; StackLoaner - Trustless Peer-to-Peer Microloans Contract
;; A smart contract system for facilitating collateralized and undercollateralized microloans

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_INVALID_DURATION (err u105))
(define-constant ERR_LOAN_NOT_ACTIVE (err u106))
(define-constant ERR_PAYMENT_FAILED (err u107))
(define-constant ERR_LOAN_ALREADY_REPAID (err u108))
(define-constant ERR_INVALID_INTEREST_RATE (err u109))

;; Data Variables
(define-data-var loan-id-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Data Maps
(define-map loans 
    uint 
    {
        borrower: principal,
        lender: principal,
        amount: uint,
        interest-rate: uint, ;; basis points (e.g., 1000 = 10%)
        duration: uint, ;; in blocks
        collateral-amount: uint,
        created-at: uint,
        due-at: uint,
        repaid-amount: uint,
        status: (string-ascii 20)
    })

(define-map borrower-stats
    principal
    {
        total-loans: uint,
        successful-repayments: uint,
        total-borrowed: uint,
        credit-score: uint
    })

(define-map lender-stats
    principal
    {
        total-loans-given: uint,
        total-amount-lent: uint,
        total-interest-earned: uint
    })

;; NFT for Credit Reputation System
(define-non-fungible-token credit-badge uint)

;; Private Functions
(define-private (calculate-total-repayment (amount uint) (interest-rate uint))
    (+ amount (/ (* amount interest-rate) u10000)))

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-rate)) u10000))

(define-private (update-borrower-stats (borrower principal) (amount uint) (is-repayment bool))
    (let ((current-stats (default-to 
                            {total-loans: u0, successful-repayments: u0, total-borrowed: u0, credit-score: u500}
                            (map-get? borrower-stats borrower))))
        (if is-repayment
            (map-set borrower-stats borrower
                {
                    total-loans: (get total-loans current-stats),
                    successful-repayments: (+ (get successful-repayments current-stats) u1),
                    total-borrowed: (get total-borrowed current-stats),
                    credit-score: (if (> (+ (get credit-score current-stats) u50) u1000) 
                                    u1000 
                                    (+ (get credit-score current-stats) u50))
                })
            (map-set borrower-stats borrower
                {
                    total-loans: (+ (get total-loans current-stats) u1),
                    successful-repayments: (get successful-repayments current-stats),
                    total-borrowed: (+ (get total-borrowed current-stats) amount),
                    credit-score: (get credit-score current-stats)
                }))))

(define-private (update-lender-stats (lender principal) (amount uint) (interest-earned uint))
    (let ((current-stats (default-to 
                            {total-loans-given: u0, total-amount-lent: u0, total-interest-earned: u0}
                            (map-get? lender-stats lender))))
        (map-set lender-stats lender
            {
                total-loans-given: (+ (get total-loans-given current-stats) u1),
                total-amount-lent: (+ (get total-amount-lent current-stats) amount),
                total-interest-earned: (+ (get total-interest-earned current-stats) interest-earned)
            })))

;; Public Functions

;; Create a new loan request
(define-public (create-loan (amount uint) (interest-rate uint) (duration uint) (collateral-amount uint))
    (let ((loan-id (+ (var-get loan-id-counter) u1))
          (current-block stacks-block-height))
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= interest-rate u5000) ERR_INVALID_INTEREST_RATE) ;; Max 50% interest
        (asserts! (and (>= duration u144) (<= duration u52560)) ERR_INVALID_DURATION) ;; 1 day to 1 year in blocks
        
        ;; Transfer collateral from borrower if required
        (if (> collateral-amount u0)
            (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
            true)
        
        ;; Create the loan record
        (map-set loans loan-id
            {
                borrower: tx-sender,
                lender: CONTRACT_OWNER, ;; Placeholder until funded
                amount: amount,
                interest-rate: interest-rate,
                duration: duration,
                collateral-amount: collateral-amount,
                created-at: current-block,
                due-at: (+ current-block duration),
                repaid-amount: u0,
                status: "pending"
            })
        
        ;; Update borrower statistics
        (update-borrower-stats tx-sender amount false)
        
        ;; Increment loan counter
        (var-set loan-id-counter loan-id)
        
        (ok loan-id)))

;; Fund a loan (lender provides funds)
(define-public (fund-loan (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_ACTIVE)
        (asserts! (not (is-eq tx-sender (get borrower loan-data))) ERR_UNAUTHORIZED)
        
        ;; Transfer loan amount from lender to borrower
        (let ((platform-fee (calculate-platform-fee (get amount loan-data))))
            (try! (stx-transfer? (get amount loan-data) tx-sender (get borrower loan-data)))
            (try! (stx-transfer? platform-fee tx-sender CONTRACT_OWNER))
            
            ;; Update loan status and lender
            (map-set loans loan-id
                (merge loan-data {lender: tx-sender, status: "active"}))
            
            (ok true))))

;; Repay loan
(define-public (repay-loan (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
        (asserts! (is-eq (get repaid-amount loan-data) u0) ERR_LOAN_ALREADY_REPAID)
        
        (let ((total-repayment (calculate-total-repayment (get amount loan-data) (get interest-rate loan-data)))
              (interest-earned (- total-repayment (get amount loan-data))))
            
            ;; Transfer repayment to lender
            (try! (stx-transfer? total-repayment tx-sender (get lender loan-data)))
            
            ;; Return collateral if any
            (if (> (get collateral-amount loan-data) u0)
                (try! (as-contract (stx-transfer? (get collateral-amount loan-data) tx-sender (get borrower loan-data))))
                true)
            
            ;; Update loan status
            (map-set loans loan-id
                (merge loan-data {repaid-amount: total-repayment, status: "repaid"}))
            
            ;; Update statistics
            (update-borrower-stats tx-sender (get amount loan-data) true)
            (update-lender-stats (get lender loan-data) (get amount loan-data) interest-earned)
            
            ;; Mint credit badge NFT for successful repayment
            (try! (nft-mint? credit-badge loan-id tx-sender))
            
            (ok true))))

;; Handle late payment penalties
(define-public (apply-late-penalty (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
        (asserts! (> stacks-block-height (get due-at loan-data)) ERR_UNAUTHORIZED)
        
        ;; Mark as overdue and apply penalty logic
        (map-set loans loan-id
            (merge loan-data {status: "overdue"}))
        
        (ok true)))

;; Read-only functions

(define-read-only (get-loan (loan-id uint))
    (map-get? loans loan-id))

(define-read-only (get-borrower-stats (borrower principal))
    (map-get? borrower-stats borrower))

(define-read-only (get-lender-stats (lender principal))
    (map-get? lender-stats lender))

(define-read-only (get-total-loans)
    (var-get loan-id-counter))

(define-read-only (calculate-repayment-amount (amount uint) (interest-rate uint))
    (calculate-total-repayment amount interest-rate))

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate))

;; Admin functions (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate u1000) (err u110)) ;; Max 10% fee
        (var-set platform-fee-rate new-rate)
        (ok true)))

(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT_OWNER)))
        (ok true)))