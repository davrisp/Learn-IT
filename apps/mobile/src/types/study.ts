
export type Flashcard = {
    id: string;
    term: string;
    definition: string;
  };

  export type StudySet = {
    id: string;
    title: string;
    description: string;
    cards: Flashcard[];
    createdAt: string;
    updatedAt: string;
  };
