;; StackLoaner - Trustless Peer-to-Peer Microloans Contract
;; A smart contract system for facilitating collateralized and undercollateralized microloans
;; Now supports multiple SIP-010 tokens as loan currency and collateral

;; SIP-010 Token Trait
(define-trait sip-010-trait
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
        (get-name () (response (string-ascii 32) uint))
        (get-symbol () (response (string-ascii 10) uint))
        (get-decimals () (response uint uint))
        (get-balance (principal) (response uint uint))
        (get-total-supply () (response uint uint))
        (get-token-uri () (response (optional (string-utf8 256)) uint))
    )
)

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
(define-constant ERR_TOKEN_NOT_SUPPORTED (err u110))
(define-constant ERR_TRANSFER_FAILED (err u111))
(define-constant ERR_INVALID_TOKEN_CONTRACT (err u112))

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
        loan-token: principal, ;; SIP-010 token contract for the loan
        collateral-token: principal, ;; SIP-010 token contract for collateral
        created-at: uint,
        due-at: uint,
        repaid-amount: uint,
        status: (string-ascii 20),
        is-stx-loan: bool, ;; true if using STX, false if using SIP-010
        is-stx-collateral: bool ;; true if collateral is STX, false if SIP-010
    })

(define-map supported-tokens principal bool)

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

;; Initialize supported tokens (STX is always supported)
;; (map-set supported-tokens 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip010-token true) ;; Example token - uncomment to add

;; Private Functions
(define-private (calculate-total-repayment (amount uint) (interest-rate uint))
    (let ((interest (/ (* amount interest-rate) u10000)))
        (+ amount interest)))

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-rate)) u10000))

(define-private (is-token-supported (token-contract principal))
    (let ((validated-contract token-contract))
        (default-to false (map-get? supported-tokens validated-contract))))

(define-private (transfer-stx-safe (amount uint) (sender principal) (recipient principal))
    (if (is-eq sender (as-contract tx-sender))
        (as-contract (stx-transfer? amount sender recipient))
        (stx-transfer? amount sender recipient)))

(define-private (transfer-sip010-safe (amount uint) (sender principal) (recipient principal) (token-contract <sip-010-trait>))
    (contract-call? token-contract transfer amount sender recipient none))

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

;; Create a new STX loan request
(define-public (create-stx-loan (amount uint) (interest-rate uint) (duration uint) (collateral-amount uint))
    (let ((loan-id (+ (var-get loan-id-counter) u1))
          (current-block stacks-block-height))
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= interest-rate u5000) ERR_INVALID_INTEREST_RATE) ;; Max 50% interest
        (asserts! (and (>= duration u144) (<= duration u52560)) ERR_INVALID_DURATION) ;; 1 day to 1 year in blocks
        
        ;; Transfer collateral from borrower if required (STX collateral)
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
                loan-token: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stx-token, ;; Placeholder for STX
                collateral-token: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stx-token, ;; Placeholder for STX
                created-at: current-block,
                due-at: (+ current-block duration),
                repaid-amount: u0,
                status: "pending",
                is-stx-loan: true,
                is-stx-collateral: true
            })
        
        ;; Update borrower statistics
        (update-borrower-stats tx-sender amount false)
        
        ;; Increment loan counter
        (var-set loan-id-counter loan-id)
        
        (ok loan-id)))

;; Create a new SIP-010 token loan request
(define-public (create-token-loan (amount uint) (interest-rate uint) (duration uint) 
                                 (collateral-amount uint) (loan-token <sip-010-trait>) 
                                 (collateral-token <sip-010-trait>) (is-stx-collateral bool))
    (let ((loan-id (+ (var-get loan-id-counter) u1))
          (current-block stacks-block-height)
          (loan-token-contract (contract-of loan-token))
          (collateral-token-contract (contract-of collateral-token)))
        
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= interest-rate u5000) ERR_INVALID_INTEREST_RATE)
        (asserts! (and (>= duration u144) (<= duration u52560)) ERR_INVALID_DURATION)
        (asserts! (is-token-supported loan-token-contract) ERR_TOKEN_NOT_SUPPORTED)
        
        ;; Transfer collateral from borrower if required
        (if (> collateral-amount u0)
            (if is-stx-collateral
                (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
                (begin
                    (asserts! (is-token-supported collateral-token-contract) ERR_TOKEN_NOT_SUPPORTED)
                    (try! (transfer-sip010-safe collateral-amount tx-sender (as-contract tx-sender) collateral-token))))
            true)
        
        ;; Create the loan record
        (map-set loans loan-id
            {
                borrower: tx-sender,
                lender: CONTRACT_OWNER,
                amount: amount,
                interest-rate: interest-rate,
                duration: duration,
                collateral-amount: collateral-amount,
                loan-token: loan-token-contract,
                collateral-token: collateral-token-contract,
                created-at: current-block,
                due-at: (+ current-block duration),
                repaid-amount: u0,
                status: "pending",
                is-stx-loan: false,
                is-stx-collateral: is-stx-collateral
            })
        
        ;; Update borrower statistics
        (update-borrower-stats tx-sender amount false)
        
        ;; Increment loan counter
        (var-set loan-id-counter loan-id)
        
        (ok loan-id)))

;; Fund an STX loan
(define-public (fund-stx-loan (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_ACTIVE)
        (asserts! (not (is-eq tx-sender (get borrower loan-data))) ERR_UNAUTHORIZED)
        (asserts! (get is-stx-loan loan-data) ERR_INVALID_TOKEN_CONTRACT)
        
        (let ((platform-fee (calculate-platform-fee (get amount loan-data))))
            ;; Transfer loan amount from lender to borrower
            (try! (stx-transfer? (get amount loan-data) tx-sender (get borrower loan-data)))
            ;; Transfer platform fee to contract owner
            (try! (stx-transfer? platform-fee tx-sender CONTRACT_OWNER))
            
            ;; Update loan status and lender
            (map-set loans loan-id
                (merge loan-data {lender: tx-sender, status: "active"}))
            
            (ok true))))

;; Fund a SIP-010 token loan
(define-public (fund-token-loan (loan-id uint) (loan-token <sip-010-trait>))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq (get status loan-data) "pending") ERR_LOAN_NOT_ACTIVE)
        (asserts! (not (is-eq tx-sender (get borrower loan-data))) ERR_UNAUTHORIZED)
        (asserts! (not (get is-stx-loan loan-data)) ERR_INVALID_TOKEN_CONTRACT)
        (asserts! (is-eq (contract-of loan-token) (get loan-token loan-data)) ERR_INVALID_TOKEN_CONTRACT)
        
        (let ((platform-fee (calculate-platform-fee (get amount loan-data))))
            ;; Transfer loan amount from lender to borrower
            (try! (transfer-sip010-safe (get amount loan-data) tx-sender (get borrower loan-data) loan-token))
            ;; Transfer platform fee to contract owner (in the same token)
            (try! (transfer-sip010-safe platform-fee tx-sender CONTRACT_OWNER loan-token))
            
            ;; Update loan status and lender
            (map-set loans loan-id
                (merge loan-data {lender: tx-sender, status: "active"}))
            
            (ok true))))

;; Repay STX loan
(define-public (repay-stx-loan (loan-id uint))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
        (asserts! (is-eq (get repaid-amount loan-data) u0) ERR_LOAN_ALREADY_REPAID)
        (asserts! (get is-stx-loan loan-data) ERR_INVALID_TOKEN_CONTRACT)
        
        (let ((total-repayment (calculate-total-repayment (get amount loan-data) (get interest-rate loan-data)))
              (interest-earned (- total-repayment (get amount loan-data))))
            
            ;; Transfer repayment to lender
            (try! (stx-transfer? total-repayment tx-sender (get lender loan-data)))
            
            ;; Return collateral if any
            (if (> (get collateral-amount loan-data) u0)
                (if (get is-stx-collateral loan-data)
                    (try! (as-contract (stx-transfer? (get collateral-amount loan-data) (as-contract tx-sender) (get borrower loan-data))))
                    true)
                true)
            
            ;; Update loan status
            (map-set loans loan-id
                (merge loan-data {repaid-amount: total-repayment, status: "repaid"}))
            
            ;; Update statistics
            (update-borrower-stats (get borrower loan-data) (get amount loan-data) true)
            (update-lender-stats (get lender loan-data) (get amount loan-data) interest-earned)
            
            ;; Mint credit badge NFT for successful repayment
            (try! (nft-mint? credit-badge loan-id (get borrower loan-data)))
            
            (ok true))))

;; Repay SIP-010 token loan
(define-public (repay-token-loan (loan-id uint) (loan-token <sip-010-trait>) (collateral-token <sip-010-trait>))
    (let ((loan-data (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan-data) "active") ERR_LOAN_NOT_ACTIVE)
        (asserts! (is-eq (get repaid-amount loan-data) u0) ERR_LOAN_ALREADY_REPAID)
        (asserts! (not (get is-stx-loan loan-data)) ERR_INVALID_TOKEN_CONTRACT)
        (asserts! (is-eq (contract-of loan-token) (get loan-token loan-data)) ERR_INVALID_TOKEN_CONTRACT)
        
        (let ((total-repayment (calculate-total-repayment (get amount loan-data) (get interest-rate loan-data)))
              (interest-earned (- total-repayment (get amount loan-data))))
            
            ;; Transfer repayment to lender
            (try! (transfer-sip010-safe total-repayment tx-sender (get lender loan-data) loan-token))
            
            ;; Return collateral if any
            (if (> (get collateral-amount loan-data) u0)
                (if (get is-stx-collateral loan-data)
                    (try! (as-contract (stx-transfer? (get collateral-amount loan-data) (as-contract tx-sender) (get borrower loan-data))))
                    (begin
                        (asserts! (is-eq (contract-of collateral-token) (get collateral-token loan-data)) ERR_INVALID_TOKEN_CONTRACT)
                        (try! (as-contract (transfer-sip010-safe (get collateral-amount loan-data) (as-contract tx-sender) (get borrower loan-data) collateral-token)))))
                true)
            
            ;; Update loan status
            (map-set loans loan-id
                (merge loan-data {repaid-amount: total-repayment, status: "repaid"}))
            
            ;; Update statistics
            (update-borrower-stats (get borrower loan-data) (get amount loan-data) true)
            (update-lender-stats (get lender loan-data) (get amount loan-data) interest-earned)
            
            ;; Mint credit badge NFT for successful repayment
            (try! (nft-mint? credit-badge loan-id (get borrower loan-data)))
            
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

;; Add supported token (admin only)
(define-public (add-supported-token (token-contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (let ((validated-contract token-contract))
            (asserts! (is-standard validated-contract) ERR_INVALID_TOKEN_CONTRACT)
            (map-set supported-tokens validated-contract true)
            (ok true))))

;; Remove supported token (admin only)
(define-public (remove-supported-token (token-contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (let ((validated-contract token-contract))
            (asserts! (is-standard validated-contract) ERR_INVALID_TOKEN_CONTRACT)
            (map-delete supported-tokens validated-contract)
            (ok true))))

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

(define-read-only (is-supported-token (token-contract principal))
    (let ((validated-contract token-contract))
        (asserts! (is-standard validated-contract) false)
        (is-token-supported validated-contract)))

;; Admin functions (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-rate u1000) ERR_INVALID_INTEREST_RATE) ;; Max 10% fee
        (var-set platform-fee-rate new-rate)
        (ok true)))

(define-public (emergency-withdraw-stx (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (let ((contract-balance (stx-get-balance (as-contract tx-sender))))
            (asserts! (<= amount contract-balance) ERR_INSUFFICIENT_FUNDS)
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) CONTRACT_OWNER)))
            (ok true))))

(define-public (emergency-withdraw-token (amount uint) (token <sip-010-trait>))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (let ((token-contract (contract-of token)))
            (asserts! (is-token-supported token-contract) ERR_TOKEN_NOT_SUPPORTED)
            (try! (as-contract (transfer-sip010-safe amount (as-contract tx-sender) CONTRACT_OWNER token)))
            (ok true))))