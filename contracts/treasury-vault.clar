;; HyperTreasury Vault
;; A secure, flexible treasury management system on the Stacks blockchain
;; Enables advanced treasury operations with robust access controls and tracking

;; =======================================
;; Constants and Error Codes
;; =======================================
(define-constant contract-owner tx-sender)

;; Error codes for treasury operations
(define-constant err-not-authorized (err u200))
(define-constant err-insufficient-funds (err u201))
(define-constant err-invalid-allocation (err u202))
(define-constant err-treasury-locked (err u203))
(define-constant err-duplicate-allocation (err u204))
(define-constant err-allocation-not-found (err u205))

;; Treasury access levels
(define-constant access-level-read u1)
(define-constant access-level-write u2)
(define-constant access-level-admin u3)

;; =======================================
;; Data Maps and Variables
;; =======================================

;; Track treasury allocations
(define-map treasury-allocations
  {
    allocation-id: uint
  }
  {
    name: (string-ascii 50),
    description: (string-utf8 200),
    budget: uint,
    spent: uint,
    access-level: uint
  }
)

;; Track authorized users and their access levels
(define-map treasury-access
  principal
  uint
)

;; Tracks total treasury balance
(define-data-var total-treasury-balance uint u0)

;; =======================================
;; Private Functions
;; =======================================

;; Check if user has required access level
(define-private (has-access-level (user principal) (required-level uint))
  (let
    (
      (user-level (default-to u0 (map-get? treasury-access user)))
    )
    (>= user-level required-level)
  )
)

;; Validate budget allocation
(define-private (validate-allocation (budget uint) (spent uint))
  (>= budget spent)
)

;; =======================================
;; Public Functions
;; =======================================

;; Add or update treasury access for a user
(define-public (set-user-access (user principal) (access-level uint))
  (begin
    (asserts! (has-access-level tx-sender access-level-admin) (err err-not-authorized))
    (asserts! (or 
                (is-eq access-level access-level-read)
                (is-eq access-level access-level-write)
                (is-eq access-level access-level-admin)
              ) (err err-not-authorized))
    (map-set treasury-access user access-level)
    (ok true)
  )
)

;; Create a new treasury allocation
(define-public (create-allocation 
                (name (string-ascii 50)) 
                (description (string-utf8 200))
                (budget uint)
                (access-level uint))
  (let
    (
      (allocation-id (var-get total-treasury-balance))
    )
    ;; Authorization check
    (asserts! (has-access-level tx-sender access-level-write) (err err-not-authorized))
    
    ;; Validation
    (asserts! (> budget u0) (err err-invalid-allocation))
    
    ;; Create allocation
    (map-set treasury-allocations 
      {allocation-id: allocation-id}
      {
        name: name,
        description: description,
        budget: budget,
        spent: u0,
        access-level: access-level
      }
    )
    
    ;; Increment total allocations
    (var-set total-treasury-balance (+ allocation-id u1))
    
    (ok allocation-id)
  )
)

;; Retrieve allocation details
(define-read-only (get-allocation (allocation-id uint))
  (let
    (
      (allocation-data (map-get? treasury-allocations {allocation-id: allocation-id}))
    )
    (match allocation-data
      data 
        (if (has-access-level tx-sender (get access-level data))
          (ok data)
          (err err-not-authorized)
        )
      (err err-allocation-not-found)
    )
  )
)

;; Spend from an allocation
(define-public (spend-allocation (allocation-id uint) (amount uint))
  (let
    (
      (allocation-data (unwrap! 
        (map-get? treasury-allocations {allocation-id: allocation-id}) 
        (err err-allocation-not-found)
      ))
    )
    ;; Authorization and validation checks
    (asserts! (has-access-level tx-sender access-level-write) (err err-not-authorized))
    (asserts! 
      (validate-allocation 
        (get budget allocation-data) 
        (+ (get spent allocation-data) amount)
      ) 
      (err err-insufficient-funds)
    )
    
    ;; Update allocation
    (map-set treasury-allocations
      {allocation-id: allocation-id}
      (merge allocation-data {spent: (+ (get spent allocation-data) amount)})
    )
    
    (ok true)
  )
)