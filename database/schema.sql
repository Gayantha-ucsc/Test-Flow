SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- 1. User
-- ============================================================================
DROP TABLE IF EXISTS `User`;
CREATE TABLE `User` (
    user_id                     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name                        VARCHAR(100)  NOT NULL,
    email                       VARCHAR(255)  NOT NULL,
    password_hash               VARCHAR(255)  NOT NULL,
    profile_picture             VARCHAR(255)  NULL,
    is_admin                    TINYINT(1)    NOT NULL DEFAULT 0,
    is_active                   TINYINT(1)    NOT NULL DEFAULT 1,
    is_temp                     TINYINT(1)    NOT NULL DEFAULT 0,
    is_temp_password_changed    TINYINT(1)    NOT NULL DEFAULT 0,
    created_at                  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_user_email (email)
)

-- ============================================================================
-- 2. WorkflowTemplate
-- ============================================================================
DROP TABLE IF EXISTS `WorkflowTemplate`;
CREATE TABLE `WorkflowTemplate` (
    workflow_template_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name                        VARCHAR(150)  NOT NULL,
    description                 TEXT          NOT NULL,
    created_by                  INT UNSIGNED  NOT NULL,
    is_system_default           TINYINT(1)    NOT NULL DEFAULT 0,
    created_at                  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_workflowtemplate_created_by
        FOREIGN KEY (created_by) REFERENCES `User`(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 3. Project
-- ============================================================================
DROP TABLE IF EXISTS `Project`;
CREATE TABLE `Project` (
    project_id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name                        VARCHAR(150)  NOT NULL,
    description                 TEXT          NOT NULL,
    created_by                  INT UNSIGNED  NOT NULL,
    workflow_template_id        INT UNSIGNED  NULL,
    deadline                    DATE          NOT NULL,
    status                      ENUM('active','archived','closed') NOT NULL DEFAULT 'active',
    created_at                  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_project_created_by
        FOREIGN KEY (created_by) REFERENCES `User`(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_project_workflow_template
        FOREIGN KEY (workflow_template_id) REFERENCES `WorkflowTemplate`(workflow_template_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 4. ProjectMember
-- ============================================================================
DROP TABLE IF EXISTS `ProjectMember`;
CREATE TABLE `ProjectMember` (
    project_member_id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    project_id                  INT UNSIGNED NOT NULL,
    user_id                     INT UNSIGNED NOT NULL,
    role                        ENUM('manager','team_lead','developer','designer','client','other') NOT NULL,
    added_by                    INT UNSIGNED NULL, -- NULL for the project creator's own membership row
    is_active                   TINYINT(1)   NOT NULL DEFAULT 1,
    joined_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_projectmember_project_user_role (project_id, user_id, role),

    CONSTRAINT fk_projectmember_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_projectmember_user
        FOREIGN KEY (user_id) REFERENCES `User`(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_projectmember_added_by
        FOREIGN KEY (added_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 5. TemplateStage
-- ============================================================================
DROP TABLE IF EXISTS `TemplateStage`;
CREATE TABLE `TemplateStage` (
    template_stage_id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name                        VARCHAR(150) NOT NULL,
    description                 TEXT         NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 6. TemplateStageMap
-- ============================================================================
DROP TABLE IF EXISTS `TemplateStageMap`;
CREATE TABLE `TemplateStageMap` (
    template_stage_map_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    workflow_template_id        INT UNSIGNED NOT NULL,
    template_stage_id           INT UNSIGNED NOT NULL,
    sequence_order              INT          NOT NULL,

    UNIQUE KEY uq_tsm_template_stage (workflow_template_id, template_stage_id),
    UNIQUE KEY uq_tsm_template_order (workflow_template_id, sequence_order),

    CONSTRAINT fk_tsm_workflow_template
        FOREIGN KEY (workflow_template_id) REFERENCES `WorkflowTemplate`(workflow_template_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_tsm_template_stage
        FOREIGN KEY (template_stage_id) REFERENCES `TemplateStage`(template_stage_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 7. Stage
-- ============================================================================
DROP TABLE IF EXISTS `Stage`;
CREATE TABLE `Stage` (
    stage_id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    project_id                  INT UNSIGNED NOT NULL,
    template_stage_id           INT UNSIGNED NULL, -- NULL allowed: fully custom stages
    name                        VARCHAR(150) NOT NULL,
    sequence_order               INT          NOT NULL,
    status                      ENUM('not_started','in_progress','pending_review','completed') NOT NULL DEFAULT 'not_started',
    auto_trigger_fired          TINYINT(1)   NOT NULL DEFAULT 0,
    auto_trigger_fired_at       TIMESTAMP    NULL DEFAULT NULL,
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at                 TIMESTAMP    NULL,

    UNIQUE KEY uq_stage_project_order (project_id, sequence_order),

    CONSTRAINT fk_stage_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_stage_template_stage
        FOREIGN KEY (template_stage_id) REFERENCES `TemplateStage`(template_stage_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 8. Task
-- ============================================================================
DROP TABLE IF EXISTS `Task`;
CREATE TABLE `Task` (
    task_id                     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stage_id                    INT UNSIGNED NOT NULL,
    name                        VARCHAR(150) NOT NULL,
    description                 TEXT         NULL,
    created_by                  INT UNSIGNED NOT NULL,
    status                      ENUM('locked','not_started','in_progress','pending_review','approved','rejected','blocked','overdue') NOT NULL DEFAULT 'locked',
    blocked_reason               TEXT         NULL,
    acknowledged                 TINYINT(1)   NOT NULL DEFAULT 0,
    task_type                   VARCHAR(50)  NOT NULL,
    deadline                    DATE         NOT NULL,
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_task_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_task_created_by
        FOREIGN KEY (created_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 9. TaskAssignment
-- ============================================================================
DROP TABLE IF EXISTS `TaskAssignment`;
CREATE TABLE `TaskAssignment` (
    task_assignment_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                     INT UNSIGNED NOT NULL,
    user_id                     INT UNSIGNED NOT NULL, -- references ProjectMember
    assigned_by                 INT UNSIGNED NOT NULL, -- references ProjectMember
    assigned_at                 TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_taskassignment_task_user (task_id, user_id),

    CONSTRAINT fk_taskassignment_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_taskassignment_user
        FOREIGN KEY (user_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_taskassignment_assigned_by
        FOREIGN KEY (assigned_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 10. TaskDependency
-- ============================================================================
DROP TABLE IF EXISTS `TaskDependency`;
CREATE TABLE `TaskDependency` (
    task_dependency_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                     INT UNSIGNED NOT NULL,
    depends_on_task_id          INT UNSIGNED NOT NULL,
    set_by                      INT UNSIGNED NOT NULL, -- references ProjectMember
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_taskdependency_task_dependson (task_id, depends_on_task_id),
    CONSTRAINT chk_taskdependency_not_self
        CHECK (task_id <> depends_on_task_id),

    CONSTRAINT fk_taskdependency_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_taskdependency_depends_on
        FOREIGN KEY (depends_on_task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_taskdependency_set_by
        FOREIGN KEY (set_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 11. ProgressNote
-- ============================================================================
DROP TABLE IF EXISTS `ProgressNote`;
CREATE TABLE `ProgressNote` (
    progress_note_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                     INT UNSIGNED NOT NULL,
    user_id                     INT UNSIGNED NOT NULL, -- references ProjectMember
    content                     TEXT         NOT NULL,
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_progressnote_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_progressnote_user
        FOREIGN KEY (user_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 12. ChatRoom  (created before ApprovalRecord/Notification/JointApprovalRequest
--     since those reference it)
-- ============================================================================
DROP TABLE IF EXISTS `ChatRoom`;
CREATE TABLE `ChatRoom` (
    chatroom_id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    room_type                   ENUM('project','stage','task','client') NOT NULL,
    project_id                  INT UNSIGNED NULL,
    stage_id                    INT UNSIGNED NULL,
    task_id                     INT UNSIGNED NULL,
    created_at                  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_chatroom_stage (stage_id),
    UNIQUE KEY uq_chatroom_task (task_id),

    CONSTRAINT fk_chatroom_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chatroom_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chatroom_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 13. ApprovalRecord
-- ============================================================================
DROP TABLE IF EXISTS `ApprovalRecord`;
CREATE TABLE `ApprovalRecord` (
    approval_record_id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                     INT UNSIGNED NULL,
    stage_id                    INT UNSIGNED NULL,
    project_id                  INT UNSIGNED NULL,
    decided_by                  INT UNSIGNED NOT NULL, -- references ProjectMember
    decision                    ENUM('approved','rejected','changes_requested') NOT NULL,
    feedback                     TEXT         NULL,
    decided_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_approvalrecord_one_target CHECK (
        (task_id    IS NOT NULL) +
        (stage_id   IS NOT NULL) +
        (project_id IS NOT NULL) = 1
    ),

    CONSTRAINT fk_approvalrecord_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_approvalrecord_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_approvalrecord_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_approvalrecord_decided_by
        FOREIGN KEY (decided_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 14. RevisionRound
-- ============================================================================
DROP TABLE IF EXISTS `RevisionRound`;
CREATE TABLE `RevisionRound` (
    revision_round_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                      INT UNSIGNED NOT NULL,
    round_number                  INT          NOT NULL,
    approval_record_id           INT UNSIGNED NULL,
    started_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at                    TIMESTAMP    NULL,

    UNIQUE KEY uq_revisionround_task_round (task_id, round_number),

    CONSTRAINT fk_revisionround_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_revisionround_approval
        FOREIGN KEY (approval_record_id) REFERENCES `ApprovalRecord`(approval_record_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 15. PaymentMilestone
-- ============================================================================
DROP TABLE IF EXISTS `PaymentMilestone`;
CREATE TABLE `PaymentMilestone` (
    payment_milestone_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    project_id                   INT UNSIGNED NOT NULL,
    stage_id                     INT UNSIGNED NULL,
    created_by                   INT UNSIGNED NOT NULL, -- references ProjectMember
    description                  TEXT         NULL,
    amount                       DECIMAL(12,2) NOT NULL,
    due_date                     DATE         NOT NULL,
    status                       ENUM('pending','requested','paid') NOT NULL DEFAULT 'pending',
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_paymentmilestone_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_paymentmilestone_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_paymentmilestone_created_by
        FOREIGN KEY (created_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 16. Payment
-- ============================================================================
DROP TABLE IF EXISTS `Payment`;
CREATE TABLE `Payment` (
    payment_id                   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payment_milestone_id         INT UNSIGNED NOT NULL,
    gateway_reference             VARCHAR(255) NOT NULL,
    amount_paid                   DECIMAL(12,2) NOT NULL,
    status                       ENUM('initiated','completed','failed') NOT NULL DEFAULT 'initiated',
    paid_at                      TIMESTAMP    NULL,
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_payment_milestone (payment_milestone_id),

    CONSTRAINT fk_payment_milestone
        FOREIGN KEY (payment_milestone_id) REFERENCES `PaymentMilestone`(payment_milestone_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 17. Comment
-- ============================================================================
DROP TABLE IF EXISTS `Comment`;
CREATE TABLE `Comment` (
    comment_id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    task_id                      INT UNSIGNED NULL,
    stage_id                     INT UNSIGNED NULL,
    user_id                      INT UNSIGNED NOT NULL, -- references ProjectMember
    parent_comment_id             INT UNSIGNED NULL,
    content                      TEXT         NOT NULL,
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_comment_one_target CHECK (
        (task_id  IS NOT NULL) +
        (stage_id IS NOT NULL) = 1
    ),

    CONSTRAINT fk_comment_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_comment_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_comment_user
        FOREIGN KEY (user_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_comment_parent
        FOREIGN KEY (parent_comment_id) REFERENCES `Comment`(comment_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 18. Notification
-- ============================================================================
DROP TABLE IF EXISTS `Notification`;
CREATE TABLE `Notification` (
    notification_id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id                       INT UNSIGNED NOT NULL, -- references User (account-level inbox)
    type                         VARCHAR(50)  NOT NULL,
    message                      TEXT         NOT NULL,
    task_id                      INT UNSIGNED NULL,
    stage_id                     INT UNSIGNED NULL,
    project_id                   INT UNSIGNED NULL,
    chatroom_id                  INT UNSIGNED NULL,
    payment_milestone_id         INT UNSIGNED NULL,
    is_read                      TINYINT(1)   NOT NULL DEFAULT 0,
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_notification_at_most_one_target CHECK (
        (task_id              IS NOT NULL) +
        (stage_id             IS NOT NULL) +
        (project_id           IS NOT NULL) +
        (chatroom_id          IS NOT NULL) +
        (payment_milestone_id IS NOT NULL) <= 1
    ),

    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id) REFERENCES `User`(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_notification_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_notification_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_notification_chatroom
        FOREIGN KEY (chatroom_id) REFERENCES `ChatRoom`(chatroom_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_notification_payment_milestone
        FOREIGN KEY (payment_milestone_id) REFERENCES `PaymentMilestone`(payment_milestone_id)
        ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 19. ActivityLog
-- ============================================================================
DROP TABLE IF EXISTS `ActivityLog`;
CREATE TABLE `ActivityLog` (
    activity_log_id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id                       INT UNSIGNED NOT NULL, -- who performed the action (references User)
    action                       VARCHAR(150) NOT NULL,
    task_id                      INT UNSIGNED NULL,
    stage_id                     INT UNSIGNED NULL,
    project_id                   INT UNSIGNED NULL,
    user_target_id                INT UNSIGNED NULL,
    details                      TEXT         NULL,
    created_at                   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_activitylog_at_most_one_target CHECK (
        (task_id        IS NOT NULL) +
        (stage_id       IS NOT NULL) +
        (project_id     IS NOT NULL) +
        (user_target_id IS NOT NULL) <= 1
    ),

    CONSTRAINT fk_activitylog_user
        FOREIGN KEY (user_id) REFERENCES `User`(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_activitylog_task
        FOREIGN KEY (task_id) REFERENCES `Task`(task_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_activitylog_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_activitylog_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_activitylog_user_target
        FOREIGN KEY (user_target_id) REFERENCES `User`(user_id)
        ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 20. StageChangeProposal
-- ============================================================================
DROP TABLE IF EXISTS `StageChangeProposal`;
CREATE TABLE `StageChangeProposal` (
    stage_change_proposal_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stage_id                      INT UNSIGNED NOT NULL,
    proposed_by                    INT UNSIGNED NOT NULL, -- references ProjectMember
    proposed_name                  VARCHAR(150) NOT NULL,
    reason                        TEXT         NULL,
    status                        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    reviewed_by                    INT UNSIGNED NULL, -- references ProjectMember
    feedback                       TEXT         NULL,
    created_at                     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at                    TIMESTAMP    NULL,

    CONSTRAINT fk_stagechangeproposal_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_stagechangeproposal_proposed_by
        FOREIGN KEY (proposed_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stagechangeproposal_reviewed_by
        FOREIGN KEY (reviewed_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 21. JointApprovalRequest
-- ============================================================================
DROP TABLE IF EXISTS `JointApprovalRequest`;
CREATE TABLE `JointApprovalRequest` (
    joint_approval_request_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    stage_id                      INT UNSIGNED NULL,
    project_id                    INT UNSIGNED NULL,
    chatroom_id                   INT UNSIGNED NULL,
    manager_id                    INT UNSIGNED NULL, -- references ProjectMember
    manager_decision               ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    manager_decided_at             TIMESTAMP    NULL,
    team_lead_id                   INT UNSIGNED NULL, -- references ProjectMember
    team_lead_decision             ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    team_lead_decided_at           TIMESTAMP    NULL,
    status                        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    created_at                     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_jointapproval_one_target CHECK (
        (stage_id    IS NOT NULL) +
        (project_id  IS NOT NULL) +
        (chatroom_id IS NOT NULL) = 1
    ),
    CONSTRAINT chk_jointapproval_at_least_one_party CHECK (
        manager_id IS NOT NULL OR team_lead_id IS NOT NULL
    ),

    CONSTRAINT fk_jointapproval_stage
        FOREIGN KEY (stage_id) REFERENCES `Stage`(stage_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_jointapproval_project
        FOREIGN KEY (project_id) REFERENCES `Project`(project_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_jointapproval_chatroom
        FOREIGN KEY (chatroom_id) REFERENCES `ChatRoom`(chatroom_id)
        ON DELETE CASCADE ON UPDATE RESTRICT,
    CONSTRAINT fk_jointapproval_manager
        FOREIGN KEY (manager_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_jointapproval_team_lead
        FOREIGN KEY (team_lead_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 22. MemberApprovalRequest
-- ============================================================================
DROP TABLE IF EXISTS `MemberApprovalRequest`;
CREATE TABLE `MemberApprovalRequest` (
    member_approval_request_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    new_member_id                  INT UNSIGNED NOT NULL, -- references User (not yet a ProjectMember)
    requested_by                   INT UNSIGNED NOT NULL, -- references ProjectMember
    requested_by_role              ENUM('manager','team_lead') NOT NULL,
    approval_required_role         ENUM('manager','team_lead') NOT NULL,
    status                        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    decided_by                     INT UNSIGNED NULL, -- references ProjectMember
    feedback                       TEXT         NULL,
    created_at                     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_at                     TIMESTAMP    NULL,

    CONSTRAINT fk_memberapprovalrequest_new_member
        FOREIGN KEY (new_member_id) REFERENCES `User`(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_memberapprovalrequest_requested_by
        FOREIGN KEY (requested_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_memberapprovalrequest_decided_by
        FOREIGN KEY (decided_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 23. Message
-- ============================================================================
DROP TABLE IF EXISTS `Message`;
CREATE TABLE `Message` (
    message_id                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    chatroom_id                   INT UNSIGNED NOT NULL,
    user_id                       INT UNSIGNED NOT NULL, -- references ProjectMember
    content                       TEXT         NOT NULL,
    sent_at                       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_message_chatroom
        FOREIGN KEY (chatroom_id) REFERENCES `ChatRoom`(chatroom_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_message_user
        FOREIGN KEY (user_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 24. ChatRoomMember
-- ============================================================================
DROP TABLE IF EXISTS `ChatRoomMember`;
CREATE TABLE `ChatRoomMember` (
    chatroom_member_id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    chatroom_id                   INT UNSIGNED NOT NULL,
    user_id                       INT UNSIGNED NOT NULL, -- references ProjectMember
    added_by                      INT UNSIGNED NULL,     -- references ProjectMember
    added_at                      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_chatroommember_room_user (chatroom_id, user_id),

    CONSTRAINT fk_chatroommember_chatroom
        FOREIGN KEY (chatroom_id) REFERENCES `ChatRoom`(chatroom_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chatroommember_user
        FOREIGN KEY (user_id) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_chatroommember_added_by
        FOREIGN KEY (added_by) REFERENCES `ProjectMember`(project_member_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 25. SystemSettings
-- ============================================================================
DROP TABLE IF EXISTS `SystemSettings`;
CREATE TABLE `SystemSettings` (
    system_settings_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    settings_key                    VARCHAR(100) NOT NULL,
    settings_value                  TEXT         NOT NULL,
    description                    TEXT         NOT NULL,
    updated_by                      INT UNSIGNED NOT NULL,
    updated_at                      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_systemsettings_key (settings_key),

    CONSTRAINT fk_systemsettings_updated_by
        FOREIGN KEY (updated_by) REFERENCES `User`(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- 26. RolePermission
-- ============================================================================
DROP TABLE IF EXISTS `RolePermission`;
CREATE TABLE `RolePermission` (
    role_permission_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role                          ENUM('user','manager','team_lead','developer','designer','client','other') NOT NULL,
    permission_key                 VARCHAR(100) NOT NULL,
    is_allowed                    TINYINT(1)   NOT NULL DEFAULT 0,
    updated_by                     INT UNSIGNED NOT NULL,
    updated_at                     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_rolepermission_role_key (role, permission_key),

    CONSTRAINT fk_rolepermission_updated_by
        FOREIGN KEY (updated_by) REFERENCES `User`(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- End of schema
-- ============================================================================

